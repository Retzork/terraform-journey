# Azure AD & SQL Virtual Network Template

## Project Overview
This project provisions an Azure Virtual Network (VNet) pre-configured with an Active Directory (AD) Domain Controller, a SQL Server VM, and a customizable number of domain-joined member VMs. It is designed to serve as a flexible baseline template for deploying AD-integrated environments in Azure. 

## Architecture / What it Creates
* **Resource Group:** Standard container for all resources (default: `ActiveDirectoryWithSQLRG`).
* **Networking:** 
  * VNet (`10.0.0.0/16`) with a custom DNS server pointing to the Domain Controller.
  * Subnet (`10.0.1.0/24`).
* **Domain Controller (`dc-01`):** 
  * Windows Server 2022 instance.
  * Static Private IP (`10.0.1.4`) and a Public IP.
  * Automatically provisions AD Domain Services and creates necessary service accounts using a custom PowerShell script.
* **SQL Server (`sql-01`):** 
  * SQL Server 2019 instance.
  * Automatically joins the domain via Azure VM Extensions.
  * Configured for Mixed Mode authentication with firewall rules for port 1433.
  * Assigns AD service accounts to SQL services using a custom script extension.
* **Member Nodes (`member-0X`):** 
  * Dynamic scaling based on the `domain_member_count` variable.
  * Automatically joins the deployed AD domain on startup via a polling script.

## Prerequisites
* Terraform `~> 3.0`
* Azure CLI installed and authenticated (`az login`).
* Sufficient Azure subscription permissions to create Compute and Network resources.

## Setup Instructions
1. Clone the repository to your local machine.
2. Initialize the Terraform workspace to download required providers.
3. Create a `terraform.tfvars` file to define sensitive and required variables:
   ```hcl
   domain_name              = "corp.local"
   admin_username           = "sysadmin"
   admin_password           = "YourComplexPass123!"
   service_account_password = "YourComplexPass123!"
   domain_member_count      = 2
   ```
4. Review the execution plan to verify the resources being created.

## Usage
Run the following commands to manage the infrastructure:

1. Initialize the project:
   terraform init

2. Preview the changes:
   terraform plan

3. Deploy the infrastructure:
   terraform apply

4. Tear down the environment:
   terraform destroy

## Variables
* `resource_group_name` (string): Name of the Azure Resource Group.
* `location` (string): Azure region for deployment (default: `southeastasia`).
* `admin_username` (string): Local administrator username for all VMs.
* `admin_password` (string): Administrator password for all VMs (Sensitive).
* `domain_name` (string): FQDN for the Active Directory domain (e.g., `corp.local`).
* `domain_member_count` (number): Amount of standard domain-joined VMs to deploy.
* `dc_vm_size` / `dc_image`: VM size and image specifications for the Domain Controller.
* `sql_vm_size` / `sql_image`: VM size and image specifications for the SQL Server.
* `member_vm_size` / `member_image`: VM size and image specifications for the Member VMs.
* `service_account_password` (string): Password assigned to AD service accounts (Sensitive).

## Outputs
*(Note: No explicit outputs are defined in the current configuration. You may want to expose the DC's Public IP or the SQL Server's Private IP.)*

## Folder Structure
* `*.tf`: Root Terraform configuration files (Main, Network, Compute modules).
* `variables.tf`: Contains all variable declarations.
* `.terraform.lock.hcl`: Dependency lock file.
* `/scripts/`:
  * `setup-dc.ps1.tftpl`: Installs AD DS and creates service accounts.
  * `setup-member.ps1.tftpl`: Waits for DC readiness and joins the domain.
  * `setup-sql.ps1.tftpl`: Configures SQL Server ports and service accounts.

## Notes / Common Issues
* **Provisioning Time:** The Domain Controller takes several minutes to promote and reboot. Member and SQL VMs are configured to wait/poll for the DC to become reachable before attempting to join the domain.
* **Security:** The default Network Security Group (NSG) only explicitly allows inbound HTTP (port 80). RDP (port 3389) is commented out and blocked from the public internet by default.
* **Credentials:** Ensure passwords meet Windows Server complexity requirements to prevent script execution failures during provisioning.
