$webIp = "${web_ip}"
$timeoutSeconds = 300
$waited = 0

# 1. Bounded Wait Loop
while ($true) {
    try {
        Invoke-WebRequest -Uri "http://$webIp/receiver" -UseBasicParsing -TimeoutSec 5 | Out-Null
        break
    }
    catch {
        Start-Sleep -Seconds 10
        $waited += 10
        if ($waited -ge $timeoutSeconds) { exit }
    }
}

Function Write-Checkpoint {
    Param([string]$Message)
    $body = @{ message = $Message } | ConvertTo-Json -Compress
    try { Invoke-RestMethod -Uri "http://$webIp/receiver?tier=db" -Method Post -Body $body -ContentType "application/json" } catch {}
}

Write-Checkpoint "Connected to Web Receiver. Starting Database Tier Initialization."

try {
    # Open Firewall FIRST so App Tier stops getting 'Connection Timeout'
    New-NetFirewallRule -DisplayName "Allow SQL" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
    Write-Checkpoint "Firewall port 1433 opened."

    # Enable SQL Authentication
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer" -Name "LoginMode" -Value 2
    Restart-Service -Name "MSSQLSERVER" -Force
    
    # CRITICAL: Wait longer for SQL to recover from service restart
    Write-Checkpoint "Waiting 30 seconds for SQL service recovery..."
    Start-Sleep -Seconds 30

    # Use a direct local connection string with Initial Catalog
    $connectionString = "Server=.;Database=master;Integrated Security=True;"
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    
    # Retry logic for the 'Open' method
    $connected = $false
    for ($i = 0; $i -lt 5; $i++) {
        try {
            $connection.Open()
            $connected = $true
            break
        }
        catch {
            Write-Checkpoint "Connection attempt $($i+1) failed, retrying..."
            Start-Sleep -Seconds 10
        }
    }

    if (-not $connected) { throw "Could not open SQL connection after retries." }

    $command = $connection.CreateCommand()

    # Step 1: Create Database
    $command.CommandText = "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'appdb') CREATE DATABASE appdb;"
    $command.ExecuteNonQuery() | Out-Null

    # Step 2: Create Login and User
    $command.CommandText = "
        USE appdb;
        IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'appuser')
        BEGIN
            CREATE LOGIN appuser WITH PASSWORD = '${db_password}', CHECK_POLICY = OFF;
        END
        IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'appuser')
        BEGIN
            CREATE USER appuser FOR LOGIN appuser;
            ALTER ROLE db_owner ADD MEMBER appuser;
        END
    "
    $command.ExecuteNonQuery() | Out-Null

    # Step 3: Schema and Data
    $command.CommandText = "
        USE appdb;
        IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Messages')
        BEGIN
            CREATE TABLE Messages (Id INT IDENTITY(1,1), Content VARCHAR(255));
            INSERT INTO Messages (Content) VALUES ('Data retrieved successfully from Database Tier via Node.js API.');
        END
    "
    $command.ExecuteNonQuery() | Out-Null

    $connection.Close()
    Write-Checkpoint "Initialization complete. Database ready."

}
catch {
    Write-Checkpoint "FATAL ERROR during DB Tier Setup: $_"
}