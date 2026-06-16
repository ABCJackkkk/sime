$port = 8080
$root = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "build\web"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Love Sim running at http://localhost:$port" -ForegroundColor Green
Write-Host "  Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan

$mime = @{
    ".html"="text/html"; ".js"="application/javascript"; ".json"="application/json"
    ".css"="text/css"; ".png"="image/png"; ".jpg"="image/jpeg"; ".ico"="image/x-icon"
    ".wasm"="application/wasm"; ".ttf"="font/ttf"; ".otf"="font/otf"
    ".frag"="text/plain"; ".bin"="application/octet-stream"
}

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $p = $req.Url.AbsolutePath.TrimStart('/')
    if ($p -eq '') { $p = 'index.html' }
    $fp = Join-Path $root $p
    if (Test-Path $fp -PathType Leaf) {
        $ext = [IO.Path]::GetExtension($fp)
        $mt = $mime[$ext]
        if (-not $mt) { $mt = "application/octet-stream" }
        $b = [IO.File]::ReadAllBytes($fp)
        $res.ContentType = $mt
        $res.ContentLength64 = $b.Length
        $res.OutputStream.Write($b, 0, $b.Length)
    } else {
        $fp2 = Join-Path $root "index.html"
        if (Test-Path $fp2) {
            $b = [IO.File]::ReadAllBytes($fp2)
            $res.ContentType = "text/html"
            $res.ContentLength64 = $b.Length
            $res.OutputStream.Write($b, 0, $b.Length)
        } else { $res.StatusCode = 404 }
    }
    $res.Close()
}
