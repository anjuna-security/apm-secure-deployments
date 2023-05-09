# Anjuna Policy Manager - Secure Deployments

In this repo you will find a collection of scripts for securely deploying the Anjuna Policy Manager on each of the major cloud providers.

Please find the instructions for each cloud provider in its own folder:

- [Azure](azure/README.md)
- AWS - TBD
- GCP - TBD

The Anjuna Policy Manager will be deployed securely inside an enclave. For technical details about our products, please visit our [documentation website](https://docs.anjuna.io).

Sign up for a live demo [here](https://www.anjuna.io/anjuna-live-demo-register)!

# What is the Anjuna Policy Manager?

The Anjuna Policy Manager enables a secret store to control access to secrets based on an application’s identity. It solves the problem of secure initial secret management by leveraging Confidential Computing capabilities.

Confidential Computing provides a powerful, unique, and automated way to eliminate the risks of secret management. Secure enclave hardware can generate an Attestation Quote, which cryptographically proves that a particular application is running in an enclave. Unlike a secret token stored in a file or environment variable, it cannot be used by an attacker even if stolen - it is analogous to biometry with liveness detection, instead of a password.

# License

This repo is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for the license's details.
