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
        if ($waited -ge $timeoutSeconds) {
            "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))] FATAL: Timeout waiting for Web Tier receiver. Aborting." | Out-File -FilePath "C:\local_fatal_error.log"
            exit
        }
    }
}

Function Write-Checkpoint {
    Param([string]$Message)
    $body = @{ message = $Message } | ConvertTo-Json
    try { Invoke-RestMethod -Uri "http://$webIp/receiver?tier=app" -Method Post -Body $body -ContentType "application/json" } catch {}
}

Write-Checkpoint "Connected to Web Receiver. Starting Application Tier Initialization."

try {
    Start-Process msiexec.exe -ArgumentList '/i https://nodejs.org/dist/v20.12.2/node-v20.12.2-x64.msi /qn' -Wait
    Write-Checkpoint "Node.js framework installed."

    New-Item -ItemType Directory -Force -Path "C:\api"
    Set-Location "C:\api"
    & "C:\Program Files\nodejs\npm.cmd" init -y | Out-Null
    & "C:\Program Files\nodejs\npm.cmd" install express mssql | Out-Null
    Write-Checkpoint "NPM packages express and mssql installed."

    $apiCode = @"
const express = require('express');
const sql = require('mssql');
const app = express();

const config = {
    user: 'appuser',
    password: '${db_password}',
    server: '${db_ip}',
    database: 'appdb',
    options: { 
        encrypt: false, 
        trustServerCertificate: true,
        connectTimeout: 15000 
    }
};

app.get('/api/data', async (req, res) => {
    let pool;
    try {
        pool = await sql.connect(config);
        const result = await pool.request().query('SELECT Content FROM Messages');
        res.json({ 
            source: 'Database Tier', 
            status: 'Success', 
            payload: result.recordset 
        });
    } catch (err) {
        // Return JSON error so Nginx doesn't throw 502
        res.status(500).json({ 
            source: 'Application Tier',
            error: 'Database Connection Failed', 
            details: err.message 
        });
    } finally {
        if (pool) pool.close();
    }
});

// Explicit error handling for the process
process.on('unhandledRejection', (reason, p) => {
    console.error('Unhandled Rejection at:', p, 'reason:', reason);
});

app.listen(3000, '0.0.0.0', () => console.log('API running on port 3000'));
"@
    Set-Content -Path "C:\api\server.js" -Value $apiCode

    # Start Node with redirection to capture startup crashes
    Start-Process "C:\Program Files\nodejs\node.exe" -ArgumentList "C:\api\server.js" -RedirectStandardError "C:\api\node_error.log" -WindowSterttyle Hidden
    New-NetFirewallRule -DisplayName "Allow Node 3000" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

    Write-Checkpoint "Node.js REST API configured. Initialization complete."
}
catch {
    Write-Checkpoint "FATAL ERROR during App Tier Setup: $_"
}