$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:3000/")
$listener.Start()

Write-Host ""
Write-Host "========================================"
Write-Host "  SuiviTravaux.app - Serveur actif"
Write-Host "  http://localhost:3000/preview.html"
Write-Host "  Ctrl+C pour arreter"
Write-Host "========================================"
Write-Host ""

$root = $PSScriptRoot

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    $localPath = $request.Url.LocalPath
    if ($localPath -eq "/") { $localPath = "/preview.html" }

    $filePath = Join-Path $root $localPath.TrimStart("/")

    if (Test-Path $filePath) {
        $content = [System.IO.File]::ReadAllBytes($filePath)

        $ext = [System.IO.Path]::GetExtension($filePath)
        $contentType = switch ($ext) {
            ".html" { "text/html; charset=utf-8" }
            ".css"  { "text/css" }
            ".js"   { "application/javascript" }
            ".json" { "application/json" }
            ".png"  { "image/png" }
            ".jpg"  { "image/jpeg" }
            ".svg"  { "image/svg+xml" }
            default { "text/plain" }
        }

        $response.ContentType = $contentType
        $response.ContentLength64 = $content.Length
        $response.OutputStream.Write($content, 0, $content.Length)
    } else {
        $response.StatusCode = 404
        $msg = [System.Text.Encoding]::UTF8.GetBytes("File not found")
        $response.OutputStream.Write($msg, 0, $msg.Length)
    }

    $response.Close()
    Write-Host "$($request.HttpMethod) $($request.Url.LocalPath)"
}
