source .tmp/env.sh
export PATH=${PWD:-}/.tmp:${PATH:-}

export APM_IP_ADDRESS="$(terraform -chdir=terraform output -raw apm_public_ip)"
export APM_PRIVATE_IP_ADDRESS="$(terraform -chdir=terraform output -raw apm_private_ip)"
export APM_HOSTNAME="$(terraform -chdir=terraform output -raw apm_hostname)"
export APM_KEYVAULT_NAME="$(terraform -chdir=terraform output -raw apm_key_vault_name)"
export APM_PORT="$(terraform -chdir=terraform output -raw apm_port)"
export APM_GROUP_NAME="$(terraform -chdir=terraform output -raw group_name)"
export APM_GALLERY_NAME="$(terraform -chdir=terraform output -raw apm_image_gallery_name)"
export APM_VNET_NAME="$(terraform -chdir=terraform output -raw apm_vnet_name)"
export APM_SUBNET_NAME="$(terraform -chdir=terraform output -raw apm_subnet_name)"
export APM_SA_NAME="$(terraform -chdir=terraform output -raw storage_account_name)"
export APM_SAC_NAME="$(terraform -chdir=terraform output -raw storage_account_container_name)"
export APM_LOCATION="$(terraform -chdir=terraform output -raw apm_location)"
export VAULT_ADDR="https://${APM_HOSTNAME}:${APM_PORT}"
export VAULT_CACERT="$(pwd)/cert.pem"
export ANJUNA_ADDR="https://${APM_HOSTNAME}:${APM_PORT}"
export ANJUNA_CACERT="$(pwd)/cert.pem"

echo -n "Verifying if APM is ready (this may take up to 5 minutes)..."
ok=""
for i in {1..30}; do
    sleep 10
    echo -n "."
    health=$(curl --cacert ${ANJUNA_CACERT} -s https://${APM_HOSTNAME}:${APM_PORT}/v1/sys/health || echo "{}")
    echo ${health} | jq -r .sealed | grep -q false || continue
    ok="yes"
    echo;
    break;
done

if [[ -z "$ok" ]] ; then
    echo "APM is not ready. Please check the logs and try again later."
    return 1
fi

echo "APM is ready!"

export ANJUNA_TOKEN="$(az keyvault secret show \
    --vault-name "${APM_KEYVAULT_NAME}" \
    --name "apm-root-token" | jq -r .value)"
export VAULT_TOKEN="${ANJUNA_TOKEN}"

echo;
echo "Root token recovered from Azure Key Vault and exported to env ANJUNA_TOKEN."
echo;
echo "The root token should be used to configure Vault's initial managing identities."
echo;
echo "After its use, run the following to destroy the root token secret:"
echo;
echo "az keyvault secret delete --vault-name ${APM_KEYVAULT_NAME} --name apm-root-token"
echo;
echo "Make sure to keep the root token in a safe place for future usage."
