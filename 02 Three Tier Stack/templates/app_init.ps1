$webIp = "${web_ip}"

while ($true) {
    try {
        Invoke-WebRequest -Uri "http://$webIp/receiver.aspx" -UseBasicParsing -TimeoutSec 5 | Out-Null
        break
    } catch {
        Start-Sleep -Seconds 5
    }
}

Function Write-Checkpoint {
    Param([string]$Message)
    try { Invoke-RestMethod -Uri "http://$webIp/receiver.aspx?tier=app" -Method Post -Body @{ message = $Message } } catch { }
}

Write-Checkpoint "Starting Application Tier Initialization."
Install-WindowsFeature -Name Web-Server, Web-Asp-Net45 -IncludeManagementTools
Write-Checkpoint "IIS and ASP.NET installed."

Start-Sleep -Seconds 10
Get-WebBinding -Name 'Default Web Site' 
Write-Checkpoint "Default Web Site bindings configured."
Start-Service -Name W3SVC -ErrorAction SilentlyContinue
Write-Checkpoint "IIS service started."
& "$env:windir\system32\inetsrv\appcmd.exe" set site /site.name:"Default Web Site" /bindings:"http/*:8080:"
Write-Checkpoint "Default Web Site configured to listen on port 8080."

$aspxContent = @"
<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%
    string connString = "Server=${db_ip};Database=appdb;User Id=appuser;Password=${db_password};TrustServerCertificate=True;";
    try {
        using (SqlConnection conn = new SqlConnection(connString)) {
            conn.Open();
            using (SqlCommand cmd = new SqlCommand("SELECT Content FROM Messages", conn)) {
                using (SqlDataReader reader = cmd.ExecuteReader()) {
                    while (reader.Read()) { 
                        Response.Write("[App Tier SQL Output]: " + reader["Content"].ToString()); 
                    }
                }
            }
        }
    } catch (Exception ex) { 
        Response.Write("Database Error: " + ex.Message); 
    }
%>
"@
Set-Content -Path 'C:\inetpub\wwwroot\Default.aspx' -Value $aspxContent
Remove-Item 'C:\inetpub\wwwroot\iisstart.htm' -Force -ErrorAction SilentlyContinue
Write-Checkpoint "Application payload configured."

New-NetFirewallRule -DisplayName "Allow App 8080" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
Write-Checkpoint "Initialization complete."