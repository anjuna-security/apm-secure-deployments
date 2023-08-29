# Anjuna Policy Manager Terraform Project

This folder defines the Terraform project that will be used to deploy the Azure infrastructure needed to run the Anjuna Policy Manager (APM) on Azure.

## 1. `aad.tf`

Defines the APM Server Managed Identity, which will be used to establish access rules to Key Vault.

Use this file to define Azure Active Directory (AAD) resources such as Service Principals.

## 2. `images.tf`

Defines a VM Image Gallery where APM VM images can be stored in Azure. Also defines the Image Definition for an APM VM Image.

Use this file to define further image related resources such as Container Registries.

## 3. `keyvault.tf`

Defines an Azure Key Vault, which will be used to store secrets such as the [APM Server's master key](../image/README.md) and other encrypted data (TLS certificates, etc.).

Currently, the file defines a Key Vault with a two access policies:
1. granting the owner the ability to use Key Vault to manage keys, secrets and certificates and encrypt data (but not decrypt it);
2. granting the APM Server Managed Identity the ability to follow a [Secure Key Release process (SKR)](../image/README.md) to decrypt data.

Use this file to define further Key Vault related resources such as access policies, secrets, etc.

## 4. `main.tf`

Defines some basic resources needed to properly create the other resources, such as a resource group and a random suffix to avoid name collisions.

This file is also used to define an Microsoft Azure Attestation endpoint, needed for APM's secure release of its master key.

## 5. `network.tf`

Defines the needed network resources for APM:

1. a virtual network;
1. a subnet;
1. a network security group;
1. a network securite access rule, allowing access to APM's APIs from your computer and also from within the subnet;
1. a public IP address;
1. a network interface with the public IP address and the network security group attached to it.

Use this file to define further network related resources such as load balancers, etc.

## 6. `outputs.tf`

Defines the outputs of the Terraform project, which will be used by the [infra.sh](../infra.sh) to configure and launch the APM Server.

## 7. `storage.tf`

Defines an Azure Storage Account, which will be used to store APM's data (such as secrets and policies). Defines also a Storage Container to store APM Server's launch logs.

The Storage Account is configured by default to allow access from all networks, but already has network rules to allow access from the subnet where APM is deployed and also your computer's Public IP Address.

In case you wish to not allow access from all networks, simply modify the `network_rules.default_action` field to `Deny`. In this case, if you are running this Terraform project from a machine in Azure from the same account, make sure to also add the machine's subnet to the `network_rules.virtual_network_subnet_ids` list.

Use this file to define further Storage Account related resources such as other containers, file shares, etc.

## 8. `variables.tf`

Defines the variables accepted by the Terraform project.
