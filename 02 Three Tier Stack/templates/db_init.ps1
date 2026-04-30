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
    try { Invoke-RestMethod -Uri "http://$webIp/receiver.aspx?tier=db" -Method Post -Body @{ message = $Message } } catch { }
}

Write-Checkpoint "Starting Database Tier Initialization."

Set-ItemProperty -Path "HKLM:\Software\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer" -Name "LoginMode" -Value 2
Restart-Service -Name "MSSQLSERVER" -Force
Start-Sleep -Seconds 15
Write-Checkpoint "SQL Server mixed authentication enabled."

$sql = @"
CREATE DATABASE appdb;
GO
USE appdb;
GO
CREATE LOGIN appuser WITH PASSWORD = '${db_password}', CHECK_POLICY = OFF;
CREATE USER appuser FOR LOGIN appuser;
ALTER ROLE db_owner ADD MEMBER appuser;
GO
CREATE TABLE Messages (Id INT IDENTITY(1,1), Content VARCHAR(255));
INSERT INTO Messages (Content) VALUES ('Sample data successfully retrieved from the Database Tier.');
GO
"@
Invoke-Sqlcmd -Query $sql
Write-Checkpoint "Database and sample data created."

New-NetFirewallRule -DisplayName "Allow SQL" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow
Write-Checkpoint "Initialization complete."