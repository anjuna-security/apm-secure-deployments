# Anjuna Policy Manager on Azure

In this folder you will find the scripts for deploying the Anjuna Policy Manager (APM) on Azure. 

The scripts defined here were designed with the goal of getting you up and running with APM as quickly and securely as possible and should be used as a general guideline for your own deployments.

Your production environment might have needs not addressed by these scripts and changes might be required. Feel free to fork this repo and customize the scripts to better accommodate your needs.

## Environment requirements

A few things are required in order to run these scripts:

1. You are running the `infra.sh` script from a Linux terminal with `bash` on `amd64` architecture.

1. You have the Azure CLI installed. If not, see the installation instructions [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).

1. You have Terraform installed. If not, see the installation instructions [here](https://learn.hashicorp.com/tutorials/terraform/install-cli).

1. You have Docker installed and usage enabled for non-sudo users. If not, see the installation instructions [here](https://docs.docker.com/engine/install/ubuntu/), making sure to follow the post installation instructions.

1. You have the `jq` utility installed. If not, see the installation instructions [here](https://stedolan.github.io/jq/download/).

1. You have at least Openssl version 1.1.1 or newer installed. If not, see the installation instructions [here](https://www.openssl.org/source/). 

1. You have successfully logged into the Azure CLI. If not, do so with:

    ```bash
    az login --use-device-code
    ```

1. You have the role *Owner* assigned on the Azure subscription that you want to use. To quickly check if you have the role, run:

    ```bash
    user=$(az ad signed-in-user show | jq -r .userPrincipalName)
    az role assignment list | jq ".[] | select(.principalName == \"${user}\" and .roleDefinitionName == \"Owner\")"
    ```

    If the output is empty, you do not have the role assigned. Please contact your Azure subscription administrator to assign the role to you.

To quickly verify if your environment is ready to deploy the Anjuna Policy Manager, run:

```bash
./infra.sh checkenv
```

Any missing requirement will be displayed by the commmand.

## Deploying the Anjuna Policy Manager

To deploy APM with the `infra.sh` script, you will need to provide your Anjuna API Token as an argument to it. You can get yours [here](https://downloads.anjuna.io). Then, run:

```bash
./infra.sh deploy --anjuna-api-token <your-api-token>
```

By running this, all necessary Azure resources will be provisioned for you by our Terraform scripts:

1. a Resource Group;
1. a Private Image Gallery;
1. a Virtual Network, Subnet, Network Interface Controller, Public IP Address, and a Network Security Group;
1. a Storage Account; 
1. an Azure Key Vault;
1. a Microsoft Azure Attestation endpoint;

The `deploy` command will also:

1. download the APM and Anjuna Azure installers;
1. define APM's master key in the Azure Key Vault with a [Secure Key Release (SKR)](image/README.md) policy;
1. build an APM docker image locally;
1. build the APM Confidential Container disk locally;
1. upload the disk to the image gallery;
1. wrap sensitive secrets with APM's master key and upload them to the Key Vault;
1. deploy the disk as an Anjuna Confidential Container.

**Note**: currently building the disk requires root privileges. If you are not running the script as root, you will be prompted for your password when building the disk image.

### Importing your own TLS certificate

If you want to use your own TLS certificate, you can do so by providing the following arguments to the `deploy` command:

```bash
./infra.sh deploy anjuna-api-token <your-api-token> --tls-pfx <path to your pfx cert> --tls-pfx-password <certificate password>
```

In this case, the hostname of the APM Server will be overwritten with the Common Name (CN) of the certificate.

**Note**: the `--tls-pfx-password` is optional in this case and will depend on whether your certificate is password protected or not.

If no password is provided, `infra.sh` expects the input certificate to be unprotected, and in order to guarantee its safety, the script will generate a strong random password, protect the PFX file with it, and store it encrypted in AKV with APM's master key.

Only PKCS12 Certificates are supported. If you have a PEM certificate and key, you can convert them to PKCS12 format with the following command:

```bash
openssl pkcs12 -inkey <path to key .pem file> -in <path to cert .pem file> -export -out cert.pfx -password pass:<certificate password>
```

## Managing the Anjuna Policy Manager

After deploying the APM, you will need to update the `/etc/hosts` file with the public IP address and host name of the APM server (defaults to `apm-server.test`). A command will be displayed at the end of a successful deployment. For example:

```bash
echo 20.237.94.226 apm-server.test | sudo tee -a /etc/hosts
```

After you apply the command to add the `/etc/hosts` entry for APM, you can start managing your secrets and enclaves with the `anjuna-policy-manager` CLI tool. Make sure to configure your terminal session first with the following command:

```bash
source client_env.sh
```

The **client_env.sh** script defines the environment variables needed by the `anjuna-policy-manager` client.

It may take a while for the APM to be up and running after deployment. You can check its status with the following command:

```bash
anjuna-policy-manager-server status
```

You can also access the APM logs with:

```bash
anjuna-azure-cli instance log --tail \
    --name apm \
    --resource-group $(terraform -chdir=terraform output -raw group_name)
```

Once APM is ready, a secret can be created with the following command:

```bash
anjuna-policy-manager secret create dek --value "test"
```

An Anjuna Enclave can be authorized to use that key with the following command:

```bash
anjuna-policy-manager authorize enclave \
    --enclave "17c6e0cf861cbfe7ceccff7dfb0f38ffedf73cafc706e7ead26f5adecf1d79f4" \
    --signer "d235ff4d5dd6e07013137186e4cd7fd097e239e33721cb537e1b8ab324cf88e0" \
    dek
```

Enclave and Signer values above are just examples.

**Note**: If you are using a fully-qualified domain name that you **own** in a public DNS registrar, instead of adding a new entry to your `/etc/hosts` file, you could update the DNS A record for the domain name to point to the APM server's public IP address.

## Upgrading the Anjuna Policy Manager

To upgrade your live APM Server to a new version, some downtime will be required. Make sure to run the following command to stop the APM Server first:

```bash
./infra.sh stop
```

Then, run your original command to deploy APM and assign a new image version:

```bash
./infra deploy ... --image-version <new version>
```

The image version must follow the [semantic versioning](https://semver.org/) format. They are unique, and the default value is `1.0.0`.

## Tearing down the Anjuna Policy Manager

To stop the Anjuna Policy Manager Confidential Container with **no** data loss, simply run:

```bash
./infra.sh stop
```

To destroy the created Azure resources, including APM Server's storage, run:

```bash
./infra.sh destroy
```

To clean up your workspace, run:

```bash
./infra.sh cleanup
```

# Customizing the Anjuna Policy Manager deployment

Please run the following to see the available command line and terraform configuration options:

```bash
./infra.sh --help
```
