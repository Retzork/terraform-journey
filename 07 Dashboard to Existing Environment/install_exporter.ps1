$Url = "https://github.com/prometheus-community/windows_exporter/releases/latest/download/windows_exporter-amd64.msi"
$Output = "C:\windows_exporter.msi"

Invoke-WebRequest -Uri $Url -OutFile $Output

$InstallArgs = '/i C:\windows_exporter.msi /quiet ENABLED_COLLECTORS="cpu,memory,os,iis,logical_disk,net,system,tcp,service"'
Start-Process -FilePath msiexec.exe -ArgumentList $InstallArgs -Wait -NoNewWindow

New-NetFirewallRule -DisplayName "Allow Prometheus Windows Exporter" -Direction Inbound -LocalPort 9182 -Protocol TCP -Action Allow

Remove-Item -Path $Output -Force