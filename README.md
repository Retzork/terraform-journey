# Terraform Cloud Infrastructure Hub

## Overview
This repository contains a collection of Infrastructure-as-Code (IaC) projects built using Terraform. The projects focus strictly on Microsoft Azure and serve as a comprehensive learning journey into cloud architecture, networking, and container orchestration.

While developed as an educational sandbox, the templates are structured to provide a solid baseline for professional environments. **Important Note:** If adapting these modules for production use, thoroughly review and harden the security configurations. Some projects intentionally disable encryption or utilize permissive Network Security Groups (NSGs) for ease of testing.

## Global Prerequisites
To deploy the configurations in this repository, you will need:
* **Terraform:** `~> 3.0` (or as specified in individual modules).
* **Azure CLI:** Installed and authenticated (`az login`).
* **Azure Subscription:** Sufficient permissions to deploy networking, compute, and Kubernetes resources.
* **Region:** By default, these projects target the `southeastasia` region.

## Project Directory

* **[01 Demo or Test](./01%20Demo%20or%20Test)**
  Initial sandbox for testing Terraform providers, syntax, and basic Azure authentication.

* **[02 Three Tier Stack](./02%20Three%20Tier%20Stack)**
  A classic three-tier architecture deploying a Web Tier (IIS), Application Tier (ASP.NET), and Database Tier (SQL Server) across isolated subnets.

* **[03 Three Tier Stack With API in between](./03%20Three%20Tier%20Stack%20With%20API%20in%20between)**
  A modernized version of the three-tier architecture replacing IIS/ASP.NET with an Nginx reverse proxy and a Node.js (Express) REST API connecting to SQL Server.

* **[04 Active Directory Environment](./04%20Active%20Directory%20Environment)**
  Automated provisioning of a Windows Server 2022 Active Directory Domain Controller alongside a dynamic number of auto-joining member VMs.

* **[05 Active Directory With Windows SQL](./05%20Active%20Directory%20With%20Windows%20SQL)**
  An extension of the AD environment that automatically provisions and joins a SQL Server 2019 instance to the domain, configuring necessary service accounts.

* **[07 Dashboard to Existing Environment](./07%20Dashboard%20to%20Existing%20Environment)**
  An observability stack deploying a Linux Ubuntu monitoring hub (Prometheus and Grafana). Designed to inject into an existing Virtual Network to monitor the performance (CPU, RAM, response time, uptime) of Windows nodes.

* **[08 Dummy](./08%20Dummy)**
  Dynamic provisioning of basic Windows Server Virtual Machines. Frequently used as target nodes to test the monitoring capabilities of Project 07.

* **[09 Hub and Spoke](./09%20Hub%20and%20Spoke)**
  An enterprise-grade Hub-and-Spoke network topology. Features VNet peering, centralized security via Azure Firewall, and custom routing logic (User Defined Routes) to govern traffic flow.

* **[10 Azure Kubernetes Service](./10%20Azure%20Kubernetes%20Service)**
  Deployment of an AKS cluster tailored for production patterns. Includes Azure CNI networking, Cluster Autoscaler, Entra ID integration, NGINX Ingress via Helm, and Horizontal Pod Autoscaler (HPA) configurations.

*(Note: Project 06 is intentionally omitted as it contained deprecated dependencies.)*

## Usage
Each folder contains its own `README.md` with specific variables, setup instructions, and deployment nuances. Navigate to the target project directory and follow the standard Terraform workflow:
1. `terraform init`
2. `terraform plan`
3. `terraform apply`
