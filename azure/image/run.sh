#!/bin/bash

set -e -o pipefail

EPID_API_KEY="${EPID_API_KEY:-"d36d1a88677c4f989162e589676b3ad4"}"
DCAP_API_KEY="${DCAP_API_KEY:-"88e02859aca140838a565b86d488ccbf"}"

function check() {
  local -r envs="APM_HOSTNAME APM_PORT APM_SA_NAME APM_KEYVAULT_NAME APM_MK_ID MAA_ENDPOINT"
  for env in ${envs}; do
    if [[ -z "${!env}" ]]; then
      echo "Missing environment variable: ${env}"
      exit 1
    fi
  done
}

function prep() {
  mkdir -p /vault/{config,plugins,tls}
  az login --identity --allow-no-subscriptions

  local -r encrypted_password="$(az keyvault secret show --vault-name "${APM_KEYVAULT_NAME}" --name "apm-tls-cert-password" | jq -r .value)"
  local -r encrypted_saa_key="$(az keyvault secret show --vault-name "${APM_KEYVAULT_NAME}" --name "apm-saa-key" | jq -r .value)"
  local -r password="$(master_key_decrypt "${encrypted_password}")"
  az keyvault secret download \
    --vault-name "${APM_KEYVAULT_NAME}" \
    --name "apm-tls-cert" \
    --file /vault/tls/cert.pfx \
    --encoding base64
  openssl pkcs12 -in /vault/tls/cert.pfx -clcerts -nokeys -passin "pass:${password}" \
    -out /vault/tls/cert.pem
  openssl pkcs12 -in /vault/tls/cert.pfx -nocerts -nodes -passin "pass:${password}" \
    -out /vault/tls/key.pem

  APM_SAA_KEY="$(master_key_decrypt "${encrypted_saa_key}")" \
    envsubst </opt/build/apm.hcl.tpl >/vault/config/config.hcl

  echo "127.0.0.1 ${APM_HOSTNAME}" >>/etc/hosts

  export VAULT_ADDR="https://${APM_HOSTNAME}:${APM_PORT}"
  export VAULT_CACERT="/vault/tls/cert.pem"

  cp /opt/anjuna/apm/bin/anjuna-policy-manager-plugin /vault/plugins
}

# `master_key_encrypt` encrypts a value using APM's master key through Azure SKR client
function master_key_encrypt() {
  local -r value="${1}"
  AzureAttestSKR -a "${MAA_ENDPOINT}" -k "${APM_MK_ID}" -s "${value}" -w
}

# `master_key_decrypt` decrypts a value using APM's master key through Azure SKR client
function master_key_decrypt() {
  local -r value="${1}"
  AzureAttestSKR -a "${MAA_ENDPOINT}" -k "${APM_MK_ID}" -s "${value}" -u
}

# `check_apm` checks the health of the APM instance before proceeding
function check_apm() {
  curl --cacert "${VAULT_CACERT}" "${VAULT_ADDR}/v1/sys/health"
}

# Ensure that Vault is ready
function verify_vault_running() {
  echo -n "Verifying Vault server is up and running"
  local status=0
  for i in {1..30}; do # wait up to 30 seconds
    sleep 1
    echo -n "."
    check_apm &>/dev/null || continue
    status=1
    break
  done
  echo

  if [[ ${status} -eq 0 ]]; then
    echo "Could not connect to the Vault."
    exit 1
  fi
}

# `akv_secret_set` sets a secret in Azure Key Vault
function akv_secret_set() {
  local -r name="${1}"
  local -r value="${2}"

  echo "Uploading secret ${name} to Azure Key Vault"
  az keyvault secret set \
    --name "${name}" \
    --vault-name "${APM_KEYVAULT_NAME}" \
    --value "${value}" &>/dev/null
}

# `secure_unseal_keys` encrypts unseal keys and uploads them to Azure Key Vault
function secure_unseal_keys() {
  # encrypt Unseal Keys using the master key and upload them to AKV as unseal-key-X
  # shellcheck disable=SC2207 # expand variables to create array
  local -r unseal_keys=($(echo "${1}" | grep "Unseal Key" | awk ' { print $4 } '))

  for i in "${!unseal_keys[@]}"; do
    local unseal_key="${unseal_keys[${i}]}"

    echo "Encrypting unseal-key-${i}"
    encrypted_unseal_key="$(master_key_encrypt "${unseal_key}")"

    akv_secret_set "apm-unseal-key-${i}" "${encrypted_unseal_key}"
  done
}

# `upload_root_token` uploads the APM root token to Azure Key Vault
function upload_root_token() {
  local -r anjuna_token="$(echo "${1}" | grep Root -m1 | cut -d ":" -f2 | cut -d " " -f2)"

  export ANJUNA_TOKEN="${anjuna_token}"
  export VAULT_TOKEN="${anjuna_token}"

  # Upload root token so that it can be accessed outside the CVM
  akv_secret_set "apm-root-token" "${anjuna_token}"
}

# `init` initializes Vault after it has been deployed
# the initialization process is defined by securely unsealing the underlying Vault instance
# and enabling the APM Plugin
function init() {
  echo "Starting Vault"

  local -r initialized="$(check_apm 2>/dev/null | jq -r .initialized)"
  if [[ "${initialized}" == "false" ]]; then
    echo "Initializing Vault ..."
    local -r init_output="$(vault operator init 2>&1)"

    # Process the init output to persist the root token and encrypted unseal keys to Azure Key Vault
    upload_root_token "${init_output}"
    secure_unseal_keys "${init_output}"

    # Unseal Vault after initialization to configure auth plugins and secret engines
    echo "Unsealing Vault after initialization"
    unseal_vault

    echo "Initializing Anjuna Policy Manager"
    APM_SHA256=$(sha256sum "/vault/plugins/anjuna-policy-manager-plugin" | cut -d' ' -f1)
    vault plugin register \
      -sha256="${APM_SHA256}" \
      -command=anjuna-policy-manager-plugin auth apm

    echo "Enabling APM auth method"
    vault auth enable apm

    echo "Enabling Anjuna APM secrets"
    vault secrets enable --path anjuna kv

    vault write "auth/apm/config" epid-api-key="${EPID_API_KEY}" &>/dev/null
    vault write "auth/apm/config" dcap-api-key="${DCAP_API_KEY}" &>/dev/null
    echo "path \"sys/mounts\" { capabilities = [\"read\"] }" |
      vault policy write anjuna-enclave-default-policy - &>/dev/null

    echo "Anjuna Policy Manager initialized!"
  fi
}

# `unseal_vault` securely unseals Vault by downloading encrypted unsealing keys
# and leveraging Azure secure key release to decrypt them
function unseal_vault() {
  local sealed
  local encrypted_unseal_key
  local unseal_key

  sealed="$(check_apm 2>/dev/null | jq -r .sealed)"
  if [[ "${sealed}" == "true" ]]; then
    echo "Unsealing vault..."

    # Unseal vault
    for i in {0..4}; do
      encrypted_unseal_key="$(az keyvault secret show \
        --vault-name "${APM_KEYVAULT_NAME}" \
        --name "apm-unseal-key-${i}" | jq -r .value)"

      unseal_key="$(master_key_decrypt "${encrypted_unseal_key}")"

      vault operator unseal "${unseal_key}"
    done

    # Ensure that vault is unsealed
    sealed="$(check_apm 2>/dev/null | jq -r .sealed)"
    if [[ "${sealed}" == "true" ]]; then
      echo "Failed to unseal vault. See previous messages for more details"
      exit 1
    fi
  else
    echo "Vault is already unsealed"
  fi
}

function forward_signals() {
  pid="$1"
  shift
  for sig; do
    # shellcheck disable=SC2064 # These variables should be expanded now
    trap "kill -s ${sig} ${pid}" "${sig}"
  done
}

check
prep

vault server -config /vault/config/config.hcl &
pid=$!

verify_vault_running
init
unseal_vault
forward_signals "${pid}" SIGTERM SIGQUIT

echo "Vault Server started!"

wait "${pid}"
