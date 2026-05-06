# Dummy VMs

## Project Overview
This project provisions a dynamic number of Azure Virtual Machines running Windows Server 2022. It serves as a dummy target environment configured to receive the Windows Exporter for Prometheus. The first VM in the deployment sequence is assigned a public IP address.

## Architecture
The Terraform configuration creates the following Azure resources:
* Resource Group: `dummyRG` in `southeastasia`.
* Virtual Network: `dummyVNet` (10.0.0.0/16).
* Subnet: `dummySubnet` (10.0.2.0/24).
* Public IP: Assigned statically to the first VM (`vm-dummy-0`).
* Network Security Group (NSG): Attached to all VMs. Inbound RDP rules are currently disabled.
* Virtual Machines: Dynamic count of `Standard_B2s_v2` instances running Windows Server 2022 Datacenter Azure Edition Core.

## Prerequisites
* Terraform installed.
* Azure CLI installed and authenticated.
* Sufficient permissions within the target Azure subscription to create network and compute resources.

## Setup Instructions
1. Clone the repository to your local machine.
2. Initialize the Terraform working directory to download the required provider plugins.
3. Create a `terraform.tfvars` file or set environment variables to define the mandatory `admin_username` and `admin_password` variables.

## Usage
Run the following commands to manage the infrastructure:

1. Initialize the project:
   terraform init

2. Preview the execution plan:
   terraform plan

3. Apply the configuration to create the resources:
   terraform apply

4. Destroy the deployed resources:
   terraform destroy

## Variables
* `vm_count` (number): Number of VMs to launch. Default is 2.
* `admin_username` (string): Administrator username for the VMs. Note: The source code description incorrectly labels this as a "Linux Hub VM".
* `admin_password` (string): Administrator password for the VMs. Note: The source code description incorrectly labels this as a "Linux Hub VM".

## Outputs
* `public_ip_address`: The static public IP address assigned to the primary VM (`vm-dummy-0`).

## Folder Structure
* `main.tf`: Contains the primary resource definitions.
* `variables.tf`: Contains variable declarations.
* `.terraform.lock.hcl`: Dependency lock file for the Terraform providers.

## Notes / Common Issues
* Network Security Group (NSG) rules for RDP access (port 3389) are intentionally commented out in `main.tf`. RDP access is disabled by default.
* Only the first Virtual Machine receives a public IP address. Subsequent VMs rely strictly on private IP addresses.
* Variable descriptions in `variables.tf` contain a copy-paste error referencing Linux, but the deployed instances are Windows Server 2022. 
* The `admin_password` variable is marked as sensitive and will be hidden from Terraform console outputs.
