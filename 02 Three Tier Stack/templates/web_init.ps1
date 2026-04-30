Install-WindowsFeature -Name Web-Server, Web-Asp-Net45 -IncludeManagementTools

$logDir = "C:\inetpub\wwwroot\logs"
New-Item -ItemType Directory -Force -Path $logDir
icacls $logDir /grant "IIS_IUSRS:(OI)(CI)M" /T

$receiverCode = @"
<%@ Page Language="C#" %>
<%@ Import Namespace="System.IO" %>
<%
    string tier = Request.QueryString["tier"];
    string message = Request.Form["message"];
    if (!string.IsNullOrEmpty(tier) && !string.IsNullOrEmpty(message)) {
        string filePath = @"C:\inetpub\wwwroot\logs\" + tier + ".txt";
        string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
        File.AppendAllText(filePath, "[" + timestamp + "] " + message + Environment.NewLine);
        Response.Write("OK");
    }
%>
"@
Set-Content -Path "C:\inetpub\wwwroot\receiver.aspx" -Value $receiverCode

Function Write-Checkpoint {
    Param([string]$Message)
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "[$Timestamp] $Message" | Out-File -FilePath "C:\inetpub\wwwroot\logs\web.txt" -Append
}

Write-Checkpoint "Web Receiver active. Installing payload."

$aspxContent = @"
<%@ Page Language="C#" %>
<%@ Import Namespace="System.Net" %>
<%@ Import Namespace="System.IO" %>
<%
    string appUrl = "http://${app_ip}:8080/";
    try {
        WebRequest request = WebRequest.Create(appUrl);
        using (WebResponse response = request.GetResponse()) {
            using (StreamReader reader = new StreamReader(response.GetResponseStream())) {
                Response.Write("<h1>Web Tier Active</h1><p>" + reader.ReadToEnd() + "</p>");
            }
        }
    } catch (Exception ex) {
        Response.Write("<h1>Web Tier Active</h1><p>Error: " + ex.Message + "</p>");
    }
%>
"@
Set-Content -Path 'C:\inetpub\wwwroot\Default.aspx' -Value $aspxContent
Remove-Item 'C:\inetpub\wwwroot\iisstart.htm' -Force -ErrorAction SilentlyContinue
Write-Checkpoint "Web initialization complete."