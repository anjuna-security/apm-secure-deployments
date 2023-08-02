# Anjuna Policy Manager Container Image

This folder defines the following Docker image artifacts for the Anjuna Policy Manager (APM):

1. The entrypoint script `run.sh`;
1. Dockerfile; and
1. APM Server config template;

## Entrypoint script and Secure Key Release (SKR)

The APM Server is intended to run within an Anjuna Confidential Container on Azure. The `run.sh` script uses the Secure Key Release (SKR) process to retrieve secrets from Azure Key Vault (AKV) using the APM Server’s attestation report. Those secrets will be released **if and only if** the SKR process is successfully completed. 

The [SKR process](https://learn.microsoft.com/en-us/azure/confidential-computing/concept-skr-attestation) is a mechanism that allows an Enclave to securely access an encryption key if the **Enclave's identity*** is attested with a remote attestation service. In this case, the remote attestation service is Microsoft Azure Attestation (MAA).

For a secure deployment of the APM Server, its **TLS private key** and its underlying Hashicorp Vault **unsealing keys** are the sensitive information protected by the SKR process.

As described [here](../README.md), the secrets are wrapped by APM's master key. In order to configure the APM Server, the `run.sh` script will leverage [a CLI tool created by Microsoft](https://github.com/Azure/confidential-computing-cvm-guest-attestation/tree/main/cvm-securekey-release-app) called `AzureAttestSKR` that accepts an MAA endpoint and the key identifier of APM's master key and do the following:

1. Download password protected TLS private key and certificate from AKV;
1. Download the encrypted password from AKV and decrypt it with `AzureAttestSKR` and use it to access the TLS private key and certificate;
1. Configure the APM Server with the decrypted TLS private key and certificate;
1. Automatically initialize APM if it has not been initialized yet:
    1. Initialize the underlying Vault and keep a record of the unsealing keys in memory;
    1. Encrypt the unsealing keys with `AzureAttestSKR` and store them, encrypted, in Azure Key Vault;
    1. Unseal the APM Server storage;
    1. Configure Anjuna Vault plugin;
    1. Store the APM Server root token in AKV to allow the deployer to manage the APM Server with the `anjuna-policy-manager` CLI tool;
1. If the APM Server has been restarted, automatically fetch the encrypted unsealing keys, decrypt them with `AzureAttestSKR`, and unseal storage;

**\*: Currently, MAA and AKV do not support definition of policies based on the software measurements (PCR values) of an Enclave. Once this support is made available by Azure, Anjuna will update this procedure to include this needed security enhancement.**

## Dockerfile

The Dockerfile specifies a multi-stage build to prepare an image that will be used to build the APM Confidential Container disk image.

The first stage of the build (`builder`) sets up common package dependencies for the next stages.

The second stage (`skr`) builds the `AzureAttestSKR` client and installs the necessary dependencies to build it.

The third and final stage (`runner`) copies the built `AzureAttestSKR` client and the `run.sh` script to the image and configures the entrypoint to be `run.sh`.

## APM Server config template

The `apm.hcl.tpl` file specifies a configuration template that will be used by the `run.sh` script to configure the APM Server. `run.sh` will replace the template variables with the appropriate values before continuing, namely:

1. APM_HOSTNAME: The hostname of the APM instance;
1. APM_PORT: The port where APM will be listening for requests;
1. APM_SA_NAME: The name of the Storage Account that will be used by the APM Server as storage backend;

The configuration also specifies that the APM Server will enforce TLS. The certificate, password protected private key, and encrypted password will be fetched from an Azure Key Vault. The encrypted password will be decrypted with `AzureAttestSKR`, and the `run.sh` script will make sure to save the `cert.pem` and the `key.pem` values at the paths expected by the config template.

