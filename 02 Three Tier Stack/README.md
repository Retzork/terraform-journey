# Azure Three-Tier Architecture

## Project Overview
This project provisions a classic three-tier web application architecture in Azure using Terraform. It deploys a Web tier (IIS), an Application tier (ASP.NET), and a Database tier (SQL Server) across isolated subnets. The project includes a custom HTTP-based logging system to monitor the automated provisioning progression of all three tiers.

## Architecture / What it Creates
* **Resource Group:** `ThreeTierRG` in `southeastasia`.
* **Networking:** 
  * VNet: `TerraformVnet` (10.0.0.0/16).
  * Subnets: `snet-web` (10.0.1.0/24), `snet-app` (10.0.2.0/24), `snet-db` (10.0.3.0/24).
* **Network Security Groups (NSGs):**
  * `nsg-web`: Allows inbound HTTP (80) from the Internet.
  * `nsg-app`: Allows inbound TCP (8080) strictly from the Web subnet.
  * `nsg-db`: Allows inbound SQL (1433) strictly from the App subnet.
* **Compute:**
  * **Web VM (`vm-web`):** Windows Server 2022 with IIS. Configured with a Public IP. Acts as the user-facing frontend and centralized log receiver.
  * **App VM (`vm-app`):** Windows Server 2022. Hosts the ASP.NET application logic on port 8080.
  * **DB VM (`vm-db`):** SQL Server 2022 on Windows Server. Automatically provisions a sample database (`appdb`) and table.

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

1. **Initialize and Deploy:**
   terraform init
   terraform plan
   terraform apply

2. **Monitor Provisioning (Custom Logging):**
   The custom script extensions run sequentially. The Web tier hosts a logging receiver. You can monitor the startup scripts by navigating to the following URLs in your browser:
   * Web Tier Logs: `http://<web_public_ip>/logs/web.txt`
   * App Tier Logs: `http://<web_public_ip>/logs/app.txt`
   * DB Tier Logs: `http://<web_public_ip>/logs/db.txt`

3. **Verify End-to-End Connectivity:**
   Once all logs indicate completion, navigate to the Web Public IP in your browser: `http://<web_public_ip>`
   * **Expected Output:** You should see a page displaying `Web Tier Active` followed by `[App Tier SQL Output]: Sample data successfully retrieved from the Database Tier.` 
   * This confirms the Web tier successfully called the App tier, and the App tier successfully queried the DB tier.

4. **Destroy:**
   terraform destroy

## Variables
* `admin_username` (string): The local administrator username for all three Virtual Machines.
* `admin_password` (string): The administrator password for the VMs and the SQL Server `appuser` account (Sensitive).

## Outputs
* `web_public_ip`: The public IP address assigned to the Web Tier VM, used for application access and log checking.

## Folder Structure
* `main_2.tf`: Contains all Azure resource definitions (Networking, NSGs, VMs).
* `variables_4.tf`: Contains variable declarations.
* `outputs_2.tf`: Contains output declarations.
* `providers.tf`: Terraform provider configuration.
* `.terraform.lock_4.hcl`: Dependency lock file.
* `templates/` (or root, depending on your final placement):
  * `web_init.ps1`: Configures IIS and the log receiver endpoint.
  * `app_init.ps1`: Configures IIS for port 8080 and sets up the ASP.NET database connection.
  * `db_init.ps1`: Configures SQL Mixed Mode authentication, creates the database, and inserts sample data.

## Notes / Common Issues
* **Provisioning Delay:** The custom data scripts (`FirstLogonCommands`) execute when the VMs boot. It will take several minutes after `terraform apply` finishes for the web server, application, and database to be fully configured and returning data. Monitor the `/logs/` endpoints to track progress.
* **Security Limitation (Internal Traffic):** While the NSGs successfully restrict traffic flows to the correct subnets, the internal communication between the Web/App tiers (HTTP over 8080) and App/DB tiers (SQL over 1433) is currently unencrypted. This is suitable for a template or proof-of-concept, but production environments should enforce HTTPS and encrypted SQL connections.
