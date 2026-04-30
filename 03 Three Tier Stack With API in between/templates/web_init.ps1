$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (Test-Path "C:\trace.log") { Remove-Item -Path "C:\trace.log" -Force }

Function Write-Trace {
    Param([string]$Message)
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "[$Timestamp] [PS] $Message" | Out-File -FilePath "C:\trace.log" -Append -Encoding UTF8
}

Write-Trace "Starting Web Tier Initialization."

try {
    Write-Trace "Downloading Node.js..."
    Invoke-WebRequest -Uri "https://nodejs.org/dist/v20.12.2/node-v20.12.2-x64.msi" -OutFile "C:\node.msi" -UseBasicParsing
    
    Write-Trace "Installing Node.js..."
    Start-Process msiexec.exe -ArgumentList '/i C:\node.msi /qn /norestart' -Wait
    $env:Path += ";C:\Program Files\nodejs\"
    
    Write-Trace "Constructing directories..."
    New-Item -ItemType Directory -Force -Path "C:\receiver" | Out-Null
    New-Item -ItemType Directory -Force -Path "C:\logs" | Out-Null

    Stop-Process -Name "node" -Force -ErrorAction SilentlyContinue

    $receiverCode = @"
const http = require('http');
const fs = require('fs');

function logTrace(msg) { fs.appendFileSync('C:\\trace.log', '[NODE] ' + msg + '\n'); }

logTrace('Process starting...');

http.createServer((req, res) => {
    logTrace('Request: ' + req.method + ' ' + req.url);
    if (req.method === 'POST') {
        const url = new URL(req.url, 'http://localhost');
        const tier = url.searchParams.get('tier');
        let body = '';
        req.on('data', chunk => body += chunk.toString('utf8'));
        req.on('end', () => {
            logTrace('Raw Body: ' + body);
            if (tier) {
                let msg = body;
                try { 
                    msg = JSON.parse(body).message || body; 
                } catch(e) {
                    logTrace('JSON parse failed, using raw string.');
                }
                try {
                    const time = new Date().toISOString().replace(/T/, ' ').replace(/\..+/, '');
                    fs.appendFileSync('C:\\logs\\' + tier + '.txt', '[' + time + '] ' + msg + '\n');
                    logTrace('Wrote to ' + tier + '.txt');
                } catch(err) {
                    logTrace('FS Write Error: ' + err.message);
                }
            }
            res.writeHead(200);
            res.end('OK');
        });
    } else {
        res.writeHead(200);
        res.end('Receiver Active');
    }
}).listen(8081, () => logTrace('Listening on port 8081'));
"@
    Set-Content -Path "C:\receiver\app.js" -Value $receiverCode
    Start-Process "C:\Program Files\nodejs\node.exe" -ArgumentList "C:\receiver\app.js" -WindowStyle Hidden

    Write-Trace "Waiting for Node.js receiver..."
    $receiverReady = $false
    for ($i = 0; $i -lt 15; $i++) {
        try {
            Invoke-WebRequest -Uri "http://127.0.0.1:8081/" -UseBasicParsing -TimeoutSec 1 | Out-Null
            $receiverReady = $true
            break
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }

    if (-not $receiverReady) {
        Write-Trace "FATAL: Node.js failed to bind."
        exit
    }

    Function Write-Checkpoint {
        Param([string]$Message)
        $jsonPayload = @{ message = $Message } | ConvertTo-Json -Compress
        try { 
            Invoke-RestMethod -Uri "http://127.0.0.1:8081/receiver?tier=web" -Method Post -Body $jsonPayload -ContentType "application/json" 
        }
        catch {
            Write-Trace "WEBHOOK ERROR ($Message): $_" 
        }
    }

    Write-Checkpoint "Logging Receiver active. Starting Web proxy installation."

    Write-Trace "Downloading Nginx..."
    Invoke-WebRequest -Uri "http://nginx.org/download/nginx-1.24.0.zip" -OutFile "C:\nginx.zip" -UseBasicParsing
    
    Stop-Process -Name "nginx" -Force -ErrorAction SilentlyContinue
    if (Test-Path "C:\nginx") { Remove-Item -Path "C:\nginx" -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Trace "Extracting Nginx..."
    Expand-Archive -Path "C:\nginx.zip" -DestinationPath "C:\" -Force
    Rename-Item -Path "C:\nginx-1.24.0" -NewName "nginx"

    $nginxConf = @"
    worker_processes  1;
    events { worker_connections  1024; }
    http {
        include       mime.types;
        default_type  application/octet-stream;
        sendfile        on;
        server {
            listen       80;
            server_name  localhost;
            location / { root html; index index.html; }
            location /logs/ { alias C:/logs/; autoindex on; }
            location /receiver { proxy_pass http://127.0.0.1:8081; }
            location /api/ { proxy_pass http://${app_ip}:3000/api/; }
        }
    }
"@
    Set-Content -Path "C:\nginx\conf\nginx.conf" -Value $nginxConf

    $htmlContent = @"
    <!DOCTYPE html>
    <html>
    <head><title>Web Tier Proxy</title><style>body { font-family: Arial; padding: 20px; } pre { background: #eee; padding: 10px; }</style></head>
    <body>
        <h1>Web Tier Active (Nginx Proxy)</h1>
        <pre id="result">Executing API request...</pre>
        <script>
            fetch('/api/data')
                .then(async r => {
                    const contentType = r.headers.get("content-type");
                    if (contentType && contentType.includes("application/json")) { return r.json(); } 
                    else { throw new Error("HTTP " + r.status + " - Proxy returned non-JSON response."); }
                })
                .then(data => document.getElementById('result').innerText = JSON.stringify(data, null, 2))
                .catch(e => document.getElementById('result').innerText = e.message);
        </script>
    </body>
    </html>
"@
    Set-Content -Path "C:\nginx\html\index.html" -Value $htmlContent

    Write-Trace "Stopping residual IIS service to free port 80..."
    Stop-Service -Name W3SVC -Force -ErrorAction SilentlyContinue
    Set-Service -Name W3SVC -StartupType Disabled -ErrorAction SilentlyContinue

    Write-Trace "Starting Nginx..."
    Set-Location "C:\nginx"
    Start-Process "C:\nginx\nginx.exe" -WindowStyle Hidden
    New-NetFirewallRule -DisplayName "Allow HTTP 80" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

    Write-Checkpoint "Nginx Proxy initialized successfully."
    Write-Trace "Web Tier Complete."

}
catch {
    Write-Trace "FATAL ERROR: $_"
    try { Write-Checkpoint "FATAL ERROR: $_" } catch {}
}