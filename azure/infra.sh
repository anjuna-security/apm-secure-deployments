#!/bin/bash

set -e -o pipefail

ARC_BASE_URL="https://api.downloads.anjuna.io/v1/releases"
TMPDIR=".tmp"
PATH=${PATH}:${TMPDIR}

# `resolve_apm_host` resolves the target hostname of the APM instance
# if a custom tls certificate is provided, it will extract the hostname from the certificate
# otherwise, it will use the default hostname apm-server.test
function resolve_apm_host() {
  if [[ -n "${APM_TLS_PFX}" ]]; then
    echo "Importing ${APM_TLS_PFX}..."
    APM_HOSTNAME=$(openssl pkcs12 -in "${APM_TLS_PFX}" -nokeys -password pass:"${APM_TLS_PFX_PASSWORD}" | grep subject | awk -F'CN = ' '{print $2}')
    echo "Host name: ${APM_HOSTNAME}"
  fi
}

# `get_latest_apm_installer` returns the latest APM installer url
function get_latest_apm_installer() {
  local -r artifact=$(wget -O- ${ARC_BASE_URL}/apm -q --header "X-Anjuna-Auth-Token: $ANJUNA_API_TOKEN" | jq -r .products[0].artifacts[0].filename)
  echo "${ARC_BASE_URL}/${artifact}"
}

# `get_latest_anjuna_azure_installer` returns the latest Anjuna installer url
function get_latest_anjuna_azure_installer() {
  local -r artifact=$(wget -O- ${ARC_BASE_URL}/azsev -q --header "X-Anjuna-Auth-Token: $ANJUNA_API_TOKEN" | jq -r .products[0].artifacts[0].filename)
  echo "${ARC_BASE_URL}/${artifact}"
}

# `download_installers` downloads the APM and the Anjuna Azure installer
function download_installers() {
  local -r apm_target=$1
  local -r anjuna_target=$2
  mkdir -p "${TMPDIR}"

  local args=""
  if [[ -n "${ANJUNA_API_TOKEN}" ]]; then
      args="X-Anjuna-Auth-Token:${ANJUNA_API_TOKEN}"
  fi

  # download apm installer if not already downloaded
  if [[ ! -f ${apm_target} ]]; then
    local -r apm_installer_url=${APM_INSTALLER_URL:-"$(get_latest_apm_installer)"}
    wget -O "${apm_target}" "${apm_installer_url}" --header "${args}"
  else
    echo "APM Installer already downloaded. Skipping."
  fi

  # download anjuna azure installer if not already downloaded
  if [[ ! -f ${anjuna_target} ]]; then
    local -r anjuna_azure_installer_url=${ANJUNA_AZURE_INSTALLER_URL:-"$(get_latest_anjuna_azure_installer)"}
    wget -O "${anjuna_target}" "${anjuna_azure_installer_url}" --header "${args}"
  else
    echo "Anjuna Azure Installer already downloaded. Skipping."
  fi
}

# `setup` prepares your environment for the deployment of APM
# it downloads the APM installer and the Anjuna installer
# it also extracts the APM installer and installs the Anjuna CLI in your environment
function setup() {
  local -r apm_target=${TMPDIR}/apm-installer.tar.gz
  local -r anjuna_target=${TMPDIR}/anjuna-azure-installer.bin

  # if an anjuna api token is not provided the user must provide the custom installer urls
  # and in that case if custom installer urls are not provided, the setup cannot proceed
  if [[ -z "${ANJUNA_API_TOKEN}" && (-z "${APM_INSTALLER_URL}" || -z "${ANJUNA_AZURE_INSTALLER_URL}") ]]; then
    echo "Missing ANJUNA_API_TOKEN. Run $0 --help for more information."
    exit 1
  fi

  download_installers "${apm_target}" "${anjuna_target}"

  # setup environment
  tar xf "${apm_target}" -C "${TMPDIR}"
  cp "${apm_target}" image/
  chmod +x "${anjuna_target}"
  ${anjuna_target} --prefix "${TMPDIR}"
  source "${TMPDIR}/env.sh"
}

# `provision` provisions the needed cloud infrastructure for the secure deployment of APM
function provision() {
  resolve_apm_host
  terraform -chdir=terraform init -upgrade

  TF_VAR_apm_hostname="${APM_HOSTNAME}" \
  TF_VAR_apm_image_version="${APM_IMAGE_VERSION}" \
  TF_VAR_apm_port="${APM_PORT}" \
    terraform -chdir=terraform apply -auto-approve
}

# `envs` exports the needed environment variables for the deployment of APM to the provisioned infrastructure
function envs() {
  output=$(terraform -chdir=terraform output -json)
  export APM_REGISTRY=$(echo "${output}" | jq -r '.registry_name.value')
  export APM_IMAGE="${APM_REGISTRY}.azurecr.io/apm-azure-sev:latest"
  export APM_HOSTNAME="$(echo "${output}" | jq -r '.apm_hostname.value')"
  export APM_PORT="$(echo "${output}" | jq -r '.apm_port.value')"
  export APM_SA_NAME=$(echo "${output}" | jq -r '.storage_account_name.value')
  export APM_SAC_NAME=$(echo "${output}" | jq -r '.storage_account_container_name.value')
  export APM_KEYVAULT_NAME=$(echo "${output}" | jq -r '.apm_key_vault_name.value')
  export APM_LOCATION=$(echo "${output}" | jq -r '.apm_location.value')
  export APM_IDENTITY_ID=$(echo "${output}" | jq -r '.apm_identity_id.value')
  export APM_GROUP_NAME=$(echo "${output}" | jq -r '.group_name.value')
  export APM_IMAGE_GALLERY=$(echo "${output}" | jq -r '.apm_image_gallery_name.value')
  export APM_IMAGE_DEFINITION=$(echo "${output}" | jq -r '.apm_image_definition_name.value')
  export APM_IMAGE_DEFINITION_ID=$(echo "${output}" | jq -r '.apm_image_definition_id.value')
  export APM_IMAGE_VERSION=$(echo "${output}" | jq -r '.apm_image_version.value')
  export APM_NIC=$(echo "${output}" | jq -r '.apm_nic_name.value')
  export APM_MASTER_KEY=$(echo "${output}" | jq -r '.apm_master_key_name.value')
  export MAA_ENDPOINT=$(echo "${output}" | jq -r '.maa_endpoint.value')
  export APM_IP_ADDRESS=$(echo "${output}" | jq -r '.apm_public_ip.value')
  export APM_PRIVATE_IP_ADDRESS=$(echo "${output}" | jq -r '.apm_private_ip.value')
}

# `master_key` creates an exportable HSM-backed master key for APM
# an skr policy is attached to the key to allow the APM enclave to use it
function master_key() {
  if ! get_master_key_id; then
    envsubst < config/skrpolicy.json.tpl > ${TMPDIR}/skrpolicy.json
    az keyvault key create \
      --exportable true \
      --vault-name "${APM_KEYVAULT_NAME}" \
      --kty RSA-HSM \
      --name "${APM_MASTER_KEY}" \
      --policy "${TMPDIR}/skrpolicy.json" \
      --protection hsm
  else
    echo "APM master key already exists. Skipping."
  fi
}

# `get_master_key_id` returns the APM master key's identifier
function get_master_key_id() {
  az keyvault key show \
    --vault-name "${APM_KEYVAULT_NAME}" \
    --name "${APM_MASTER_KEY}" | jq -r .key.kid
}

# `master_key_encrypt_akv` encrypts a value using APM's master key through az CLI
function master_key_encrypt_akv() {
  local -r value=${1}

  # NOTE: SKR client in the enclave uses RSA-OAEP-256 algorithm
  az keyvault key encrypt \
      --name "${APM_MASTER_KEY}" \
      --vault-name "${APM_KEYVAULT_NAME}" \
      --algorithm RSA-OAEP-256 \
      --data-type plaintext \
      --value "${value}" | jq -r .result
}

# `build` builds the APM Docker Image and Confidential Container Disk
function build() {
  local -r image_name="anjuna/apm-azure-sev:${APM_IMAGE_VERSION}"
  echo "Building APM Docker Image..."
  docker build -t "${image_name}" -f "image/Dockerfile" "image"

  echo "Building the APM Disk (root privileges required)..."
  rm -f "${TMPDIR}/enclave.yaml"
  APM_MASTER_KEY_ID=$(get_master_key_id) \
    envsubst < config/enclave.yaml.tpl > ${TMPDIR}/enclave.yaml
  anjuna-azure-cli disk create \
    --docker-uri "${image_name}" \
    --disk-size "${APM_DISK_SIZE}" \
    --config "${TMPDIR}/enclave.yaml" \
    --disk "${TMPDIR}/disk.vhd" \
    --save-measurements "${TMPDIR}/measurements.json"
}

# `upload` uploads the APM Confidential Container Disk to the APM gallery
function upload() {
  echo "Uploading the APM Disk..."
  anjuna-azure-cli disk upload \
    --disk ${TMPDIR}/disk.vhd \
    --image-definition "${APM_IMAGE_DEFINITION}" \
    --image-gallery "${APM_IMAGE_GALLERY}" \
    --image-name "${APM_IMAGE_DEFINITION}" \
    --image-version "${APM_IMAGE_VERSION}" \
    --resource-group "${APM_GROUP_NAME}" \
    --storage-container "${APM_SAC_NAME}" \
    --storage-account "${APM_SA_NAME}" \
    --location "${APM_LOCATION}"
}

# `generate_pfx` generates a TLS certificate and key in a pfx archive, protected
# using the password provided, and returns the path
function generate_pfx() {
  local -r password=${1}

  local -r tlsdir=$TMPDIR/tls
  mkdir -p ${tlsdir}

  envsubst < config/csr.conf.tpl > "${tlsdir}/csr.conf"
  envsubst < config/cert.conf.tpl > "${tlsdir}/cert.conf"

  openssl req -x509 \
    -sha256 \
    -days 356 \
    -nodes \
    -newkey rsa:2048 \
    -subj "/CN=localhost/C=US/L=Palo Alto" \
    -keyout ${tlsdir}/rootCA.key \
    -out ${tlsdir}/rootCA.crt
  openssl genrsa -out ${tlsdir}/key.pem 2048
  openssl req -new \
    -key ${tlsdir}/key.pem \
    -out ${tlsdir}/server.csr \
    -config ${tlsdir}/csr.conf
  openssl x509 -req \
    -sha256 \
    -days 356 \
    -in ${tlsdir}/server.csr \
    -CA ${tlsdir}/rootCA.crt \
    -CAkey ${tlsdir}/rootCA.key \
    -CAcreateserial \
    -out ${tlsdir}/cert.pem \
    -extfile ${tlsdir}/cert.conf
  openssl pkcs12 \
    -inkey ${tlsdir}/key.pem \
    -in ${tlsdir}/cert.pem \
    -export \
    -out "${tlsdir}/cert.pfx" \
    -password "pass:${password}"

  echo "${tlsdir}/cert.pfx"
}

# `tls` stores the pfx archive and its encrypted password in the APM Key Vault
# if the pfx that is provided is not password protected, a password is generated and a new pfx is created using that password
# if no pfx is provided, both are genrated
function tls() {
  local -r password=${APM_TLS_PFX_PASSWORD:-$(openssl rand -base64 24)}

  if [[ -z "${APM_TLS_PFX}" ]]; then
    echo "Generating TLS certificate and private key..."
    APM_TLS_PFX=$(generate_pfx "${password}")
  elif [[ -z "${APM_TLS_PFX_PASSWORD}" ]]; then
    local tlsdir=$TMPDIR/tls
    mkdir -p ${tlsdir}
    openssl pkcs12 -in "${APM_TLS_PFX}" -out ${tlsdir}/temp.pem -nodes -password "pass:"
    openssl pkcs12 -export -out ${tlsdir}/cert.pfx -in ${tlsdir}/temp.pem -password "pass:${password}"
    APM_TLS_PFX=${tlsdir}/cert.pfx
  fi

  local -r encrypted_password=$(master_key_encrypt_akv "${password}")

  echo "Storing encrypted pfx password..."
  az keyvault secret set --vault-name "${APM_KEYVAULT_NAME}" --name apm-tls-cert-password --value "${encrypted_password}"
  echo "Storing pfx..."
  az keyvault secret set --vault-name "${APM_KEYVAULT_NAME}" --name apm-tls-cert --value "$(base64 -w 0 "${APM_TLS_PFX}")"

  openssl pkcs12 -in "${APM_TLS_PFX}" -out cert.pem -nodes -nokeys -password "pass:${password}"
}

# `saa_key` stores the Storage Account Access Key encrypted in the APM Key Vault
function saa_key() {
  local -r key=$(terraform -chdir=terraform output -raw storage_account_access_key)
  local -r encrypted_saa_key=$(master_key_encrypt_akv "${key}")

  echo "Storing encrypted Storage Account Access Key..."
  az keyvault secret set --vault-name "${APM_KEYVAULT_NAME}" --name apm-saa-key --value "${encrypted_saa_key}"
}

# `prep` prepares the needed APM deployment infra
function prep() {
  setup
  provision
  envs
  master_key
  if [[ -z "${SKIP_IMAGE}" ]]; then
    build
    upload
  fi
  tls
  saa_key
}

# `instruct` instructs the user on how to add the APM server IP and host name to their /etc/hosts
function instruct() {
  rm -f client_env.sh
  cp config/client_env.sh.tpl client_env.sh

  echo "--------------------------------------------------------------------------------"
  echo "Please run the following command to add the APM server IP and host name to your /etc/hosts:"
  echo;
  echo "  echo ${APM_IP_ADDRESS} ${APM_HOSTNAME} | sudo tee -a /etc/hosts"
  echo;
  echo "This enables the APM client to communicate securely with the APM Server from your environment with TLS."
  echo;
  echo "Run the following commands before future invocations of the anjuna-policy-manager client:"
  echo;
  echo "  source client_env.sh"
  echo;
  echo "--------------------------------------------------------------------------------"
}

# `deploy` sets up your environment, provisions the needed cloud infrastructure
# and ultimately deploys APM as an Anjuna Confidential Container
function deploy() {
  checkenv && echo "Environment is ready for deployment" || exit 1
  prep
  az vm create \
    --resource-group "${APM_GROUP_NAME}" \
    --name "apm" \
    --boot-diagnostics-storage "${APM_SA_NAME}" \
    --size "Standard_DC4as_v5" \
    --enable-vtpm true \
    --image "${APM_IMAGE_DEFINITION_ID}/versions/${APM_IMAGE_VERSION}" \
    --specialized \
    --public-ip-sku Standard \
    --security-type ConfidentialVM \
    --os-disk-security-encryption-type VMGuestStateOnly \
    --enable-secure-boot true \
    --nics "${APM_NIC}" \
    --assign-identity "${APM_IDENTITY_ID}" \
    --os-disk-delete-option delete
  instruct
}

# `stop` stops the APM Confidential Container instance
function stop() {
  group_name=$(terraform -chdir=terraform output -raw group_name)
  echo "Stopping APM. This may take a while..."
  az vm delete -y -g "${group_name}" -n apm
}

# `remove_image_versions` removes all APM image versions from the APM gallery
function remove_image_versions() {
  local -r version_ids=$(az sig image-version list --gallery-image-definition "${APM_IMAGE_DEFINITION}" --gallery-name "${APM_IMAGE_GALLERY}" -g "${APM_GROUP_NAME}" | jq -r '.[].id')
  for id in ${version_ids}; do
    version=$(basename "${id}")
    echo "Deleting image ${APM_IMAGE_DEFINITION}:${version}..."
    az sig image-version delete \
      --gallery-image-definition "${APM_IMAGE_DEFINITION}" \
      --gallery-image-version "${version}" \
      --gallery-name "${APM_IMAGE_GALLERY}" \
      --resource-group "${APM_GROUP_NAME}"
  done
}

# `destroy` destroys the provisioned cloud infrastructure
function destroy() {
  envs
  stop
  remove_image_versions
  terraform -chdir=terraform destroy -auto-approve
  rm -rf terraform/.terraform terraform/terraform.tfstate terraform/terraform.tfstate.backup terraform/.terraform.lock.hcl
}

# `cleanup` cleans up your local environment
function cleanup() {
  if [[ -f "terraform/terraform.tfstate" ]]; then
    echo "Aborting cleanup. Terraform state is still present. Please run 'destroy' command first."
    exit 1
  fi

  # remove files
  rm -rf image/apm-installer.tar.gz ${TMPDIR} config/apm.arm.json client_env.sh cert.pem

  # remove build containers
  local -r build_containers=$(docker ps -q -a -f name=anjuna-apm-azure-sev-"${APM_IMAGE_VERSION}"-*)
  for container in ${build_containers}; do
    docker rm "${container}"
  done

  # remove docker images
  local -r images=$(docker image ls -q -f reference=anjuna/apm-azure-sev)
  for image in ${images}; do
    docker image rm "${image}"
  done
}

# `checkenv` verifies if your environment is ready for deploying APM
function checkenv() {
  local nok=0
  if ! (uname -m | grep -q x86); then
    echo "Please run this script on an x86 machine."
    nok=1
  fi
  if ! (echo "${SHELL}" | grep -q bash); then
    echo "Please run this script with bash."
    nok=1
  fi
  if [[ -z "$(which az)" ]]; then
    echo "Please install the Azure CLI."
    nok=1
  fi
  if [[ -z "$(which terraform)" ]]; then
    echo "Please install Terraform."
    nok=1
  fi
  if [[ -z "$(which docker)" ]]; then
    echo "Please install Docker."
    nok=1
  fi
  if [[ -z "$(which jq)" ]]; then
    echo "Please install jq."
    nok=1
  fi
  if [[ -z "$(which openssl)" ]]; then
    echo "Please install Openssl v 1.1.1 or newer."
    nok=1
  fi
  if [[ -z "$(az account show)" ]]; then
    echo "Please login to Azure."
    nok=1
  fi
  return ${nok}
}

function usage(){
  cat <<EOF
Usage:
 $0 <command> <options>

Available commands (only one command can be specified)):
  deploy
    Prepares your local environment, provisions the required cloud infrastructure
    and deploys APM as an Anjuna Confidential Container instance.
  stop
    stops the APM Confidential Container instance.
  destroy
    destroys the APM Confidential Container instance and all the resources created by terraform.
  cleanup
    cleans up your workspace to free disk space. This command will fail if the destroy command was not run beforehand.
  checkenv
    verifies whether your environment is ready for deploying APM.

Available options:
  -h, --help
    prints this help.
  --hostname <hostname>
    Hostname of the APM Confidential Container instance. Defaults to "${APM_HOSTNAME}".
  --anjuna-api-token <token>
    Anjuna Resource Center API token.
    If not specified and no alternative installer urls are provided, $0 exits with error.
  --port <port number>
    HTTP Port number that APM listens to. Defaults to "${APM_PORT}".
  --image-version <version>
    Overrides the disk image version of the APM. Defaults to "${APM_IMAGE_VERSION}".
  --disk-size <size>
    Overrides the disk size of the APM. Defaults to "${APM_DISK_SIZE}".
  --tls-pfx <pkcs12 tls cert file>
    Path to the TLS PFX archive to be used by the APM server. If not provided, generates a new one by default (not recommended for production use).
  --tls-pfx-password <password>
    Password to open/protect the TLS PFX archive. A random password is generated by default.
  --anjuna-azure-installer-url "<url>"
    Overrides the URL to be used to download the Anjuna Azure CLI installer. Make sure to use quotes around the url to avoid shell expansion.
  --apm-installer-url "<url>"
    Overrides the URL to be used to download the APM installer. Make sure to use quotes around the url to avoid shell expansion.
  --skip-image
    If provided, skips the build and upload of the APM Confidential Container disk image.

  You can override the terraform variables by setting the corresponding environment variables with
    export TF_VAR_<variable_1>=<value_1>
    export TF_VAR_<variable_2>=<value_2>
    ...
    $0 <command>

  or by running the script with
    TF_VAR_<variable_1>=<value_1> \\
    TF_VAR_<variable_2>=<value_2> \\
    ... \\
      $0 <command>

  Here's the list of all available variables:
$(grep -E 'variable "[a-zA-Z0-9_]+"' terraform/variables.tf | sed -E 's/\{//g' | cut -d " " -f2 | sed 's/^/    /g')

  Refer to terraform/variables.tf for more details on each variable.
EOF
}

OPERATION=usage
APM_HOSTNAME=${TF_VAR_apm_host:-$(grep apm_host -A2 terraform/variables.tf | awk -F'"' '/default/ {print $2}')}
APM_PORT=${TF_VAR_apm_port:-$(grep apm_port -A2 terraform/variables.tf | awk -F'"' '/default/ {print $2}')}
APM_IMAGE_VERSION="1.0.0"
APM_DISK_SIZE="20G"
ANJUNA_API_TOKEN=""
APM_TLS_PFX=""
APM_TLS_PFX_PASSWORD=""
ANJUNA_AZURE_INSTALLER_URL=""
APM_INSTALLER_URL=""
SKIP_IMAGE=""
while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help) usage; exit 0;;

  deploy)       OPERATION=deploy;;
  stop)         OPERATION=stop;;
  destroy)      OPERATION=destroy;;
  cleanup)      OPERATION=cleanup;;
  checkenv)     OPERATION=checkenv;;

  --hostname)                   APM_HOSTNAME="$2"; shift;;
  --port)                       APM_PORT="$2"; shift;;
  --image-version)              APM_IMAGE_VERSION="$2"; shift;;
  --disk-size)                  APM_DISK_SIZE="$2"; shift;;
  --anjuna-api-token)           ANJUNA_API_TOKEN="$2"; shift;;
  --tls-pfx)                    APM_TLS_PFX="$2"; shift;;
  --tls-pfx-password)           APM_TLS_PFX_PASSWORD="$2"; shift;;
  --anjuna-azure-installer-url) ANJUNA_AZURE_INSTALLER_URL="$2"; shift;;
  --apm-installer-url)          APM_INSTALLER_URL="$2"; shift;;
  --skip-image)                 SKIP_IMAGE="yes";; 
  *)
    echo "Unknown option: $1"
    usage
    exit 1
    ;;
  esac
  shift
done

# Execute the requested operation
$OPERATION;
