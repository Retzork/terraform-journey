# Azure API-Based Three-Tier Architecture

## Project Overview
This project provisions a three-tier application architecture in Azure using Terraform. It utilizes an Nginx reverse proxy and a Node.js Express API to facilitate communication with a SQL Server database. This stack replaces previous IIS and ASP.NET implementations to improve overall ease of use. The project includes automated provisioning scripts and a custom HTTP-based logging system.

## Architecture / What it Creates
* Resource Group: `ThreeTierAPIRG` in `southeastasia`.
* Networking: 
  * VNet: `TerraformVnet` (10.0.0.0/16).
  * Subnets: `snet-web` (10.0.1.0/24), `snet-app` (10.0.2.0/24), `snet-db` (10.0.3.0/24).
* Network Security Groups (NSGs):
  * `nsg-web`: Allows inbound HTTP (80) from the Internet and the Virtual Network.
  * `nsg-app`: Allows inbound TCP (3000) strictly from the Web subnet.
  * `nsg-db`: Allows inbound SQL (1433) strictly from the App subnet.
* Compute:
  * Web VM (`vm-web`): Windows Server 2022 hosting Nginx and a Node.js logging receiver. Configured with a Public IP.
  * App VM (`vm-app`): Windows Server 2022 hosting the Node.js Express REST API on port 3000.
  * DB VM (`vm-db`): SQL Server 2022 on Windows Server. Automatically provisions a sample database (`appdb`) and table.

## Prerequisites
* Terraform `~> 3.0` installed.
* Azure CLI installed and authenticated.
* Sufficient Azure subscription permissions to create Compute and Network resources.

## Setup Instructions
1. Clone the repository to your local machine.
2. Initialize the Terraform directory to download required providers.
3. Create a `terraform.tfvars` file to define the required credentials:
   admin_username = "sysadmin"
   admin_password = "YourComplexPass123!"

## Usage
Run the following commands to manage the infrastructure:

1. Initialize and Deploy:
   terraform init
   terraform plan
   terraform apply

2. Monitor Provisioning:
   The provisioning scripts take several minutes to execute. To check the internal initialization trace log on the Web VM directly from your terminal, use the Azure CLI `run-command` extension:
   
   az vm run-command invoke --resource-group ThreeTierAPIRG --name vm-web --command-id RunPowerShellScript --scripts "Get-Content C:\trace.log"
   
   Alternatively, monitor the tier-specific logs via your browser:
   * `http://<web_public_ip>/logs/web.txt`
   * `http://<web_public_ip>/logs/app.txt`
   * `http://<web_public_ip>/logs/db.txt`

3. Verify End-to-End Connectivity:
   Once all logs indicate completion, navigate to the Web Public IP in your browser: `http://<web_public_ip>`
   Expected Output: The page will execute a fetch request to the API and render a JSON response. You should look for important key-value pairs confirming success, specifically `"source": "Database Tier"` and `"status": "Success"`, alongside the payload data.

4. Destroy:
   terraform destroy

## Variables
* `admin_username` (string): The local administrator username for all three Virtual Machines.
* `admin_password` (string): The administrator password for the VMs and the SQL Server `appuser` account (Sensitive).

## Outputs
* `web_public_ip`: The public IP address assigned to the Web Tier VM, used for application access and log checking.

## Folder Structure
* `main_3.tf`: Contains all Azure resource definitions (Networking, NSGs, VMs).
* `variables_5.tf`: Contains variable declarations.
* `outputs_3.tf`: Contains output declarations.
* `providers_2.tf`: Terraform provider configuration.
* `.terraform.lock_5.hcl`: Dependency lock file.
* `templates/` 
  * `web_init_2.ps1`: Configures Node.js, the logging receiver, and the Nginx proxy.
  * `app_init_2.ps1`: Configures Node.js and the Express REST API.
  * `db_init_2.ps1`: Configures SQL Mixed Mode authentication, creates the database, and inserts sample data.

## Notes / Common Issues
* Database Security Limitation: The Node.js database configuration in the Application Tier explicitly sets `encrypt: false`. Users must be aware that this results in unencrypted internal traffic between the App and DB tiers. Production environments must enforce encrypted SQL connections.
* Startup Timing: The custom script extensions contain bounded wait loops. The App and DB tiers will repeatedly poll the Web tier until the logging receiver is active before proceeding with their own installations.
