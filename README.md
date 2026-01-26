# Anjuna Policy Manager - Secure Deployments

In this repo you will find a collection of scripts for securely deploying HashiCorp Vault and the Anjuna Policy Manager on each of the major cloud providers.

You can find the instructions for deploying Vault and the Anjuna Policy Manager on a Confidential Container in Azure with AMD SEV-SNP Confidential VMs [here](azure/README.md). More platforms are planned to be supported in the future.

HashiCorp Vault will be deployed securely inside a Secure Enclave. For technical details about our products, please visit our [documentation website](https://docs.anjuna.io).

Sign up for a live demo [here](https://www.anjuna.io/anjuna-live-demo-register)!

# What is the Anjuna Policy Manager?

The Anjuna Policy Manager is a Confidential Computing-backed authentication plugin for HashiCorp Vault, allowing customers to verify the identity
of their Anjuna Confidential Containers and Anjuna Confidential Pods (attestation), and through that, solve the problem of secure initial secret distribution
to applications.

Confidential Computing provides a powerful, unique, and automated way to eliminate the risks of secret management.
Secure enclave hardware can generate an Attestation report, which cryptographically proves that a particular application is running in a secure enclave, as well as the application identity.
Unlike a secret token stored in a file or environment variable, the Attestation Report cannot be used by an attacker even if stolen - it is analogous to biometry with liveness detection, instead of a password.

# License

This repo is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for the license's details.
