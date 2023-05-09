# APM Container Image

This folder defines APM's image artifacts:

1. The entrypoint script `run.sh`;
1. Dockerfile; and
1. APM Server config template;

## Entrypoint script and Secure Key Release (SKR)

The `run.sh` script as the name suggests is responsible for running APM and it was designed to be executed from within an Anjuna Confidential Container on Azure, such that any sensitive secrets can be securely accessed by APM **if and only if** a Secure Key Release (SKR) process is successfully completed.

The SKR process is a mechanism that allows an enclave to securely access an encryption key if the enclave's identity is attested with a remote attestation service. In this case, the remote attestation service is Microsoft Azure Attestation (MAA).

For a secure deployment of APM, its **TLS private key** and its underlying Vault **unsealing keys** are the sensitive information that must be protected by an SKR process.

In order to achieve that, the `run.sh` script will leverage a Microsoft tool called `AzureAttestSKR` that accepts a MAA endpoint and the key identifier of the key to be released (APM's master key).

The script also takes care of the following:

1. Download password protected TLS private key and certificate from Key Vault;
1. Download the encrypted password from Key Vault and decrypt it with `AzureAttestSKR` and use it to access the TLS private key and certificate;
1. Configure APM Server with the decrypted TLS private key and certificate;
1. Automatically initialize APM if it has not been initialized yet:
    1. Initialize the underlying Vault and keep a record of the unsealing keys in memory;
    1. Encrypt the unsealing keys with `AzureAttestSKR` and store them in the encrypted in Key Vault;
    1. Unseal APM Server storage;
    1. Configure Anjuna Vault plugin;
    1. Store the APM Server root token in Key Vault to be used by the admin's `anjuna-policy-manager` client to further configure APM;
1. If APM Server VM has been restarted, automatically fetch the encrypted unsealing keys, decrypt them with `AzureAttestSKR` and unseal storage;

## Dockerfile

The Dockerfile specifies a multi-stage build to prepare a image that will be used to build the APM Confidential Container disk image.

The first stage of the build (`builder`) sets up common package depedencies for the next stages.

The second stage (`skr`), builds the `AzureAttestSKR` client and install the necessary dependencies to build it.

The third and final stage (`runner`), copies the built `AzureAttestSKR` client and the `run.sh` script to the image and configures the entrypoint to be `run.sh`.

## APM Server config template

The `apm.hcl.tpl` specifies a configuration template that will be used by the `run.sh` script to configure the APM Server. The `run.sh` will make sure to replace the template variables with the appropriate values before continuing, namely:

1. APM_HOSTNAME: The hostname of the APM instance;
1. APM_PORT: The port where APM will be listening for requests;
1. APM_SA_NAME: the name of the Storage Account that will be used by APM as storage backend;

The configuration also specifies that the APM Server will enforce TLS. The certificate, password protected private key and encrypted password will be fetched from Key Vault. The encrypted password will decrypted with `AzureAttestSKR`, and the `run.sh` will make sure to save the `cert.pem` and the `key.pem` values at the paths expected by the config template.

