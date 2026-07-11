$port = 8767
$root = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "build\web"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Love Sim: http://localhost:$port" -ForegroundColor Green
$mime = @{".html"="text/html"; ".js"="text/javascript"; ".json"="application/json"; ".css"="text/css"; ".png"="image/png"; ".jpg"="image/jpeg"; ".ico"="image/x-icon"; ".wasm"="application/wasm"; ".ttf"="font/ttf"; ".otf"="font/otf"}
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $p = $ctx.Request.Url.AbsolutePath.TrimStart('/')
  if ($p -eq '') { $p = 'index.html' }
  $fp = Join-Path $root $p
  if (Test-Path $fp -PathType Leaf) {
    $b = [IO.File]::ReadAllBytes($fp)
    $ctx.Response.ContentType = if ($mime.ContainsKey([IO.Path]::GetExtension($fp))) { $mime[[IO.Path]::GetExtension($fp)] } else { "application/octet-stream" }
    $ctx.Response.ContentLength64 = $b.Length
    $ctx.Response.OutputStream.Write($b, 0, $b.Length)
  } else {
    $ctx.Response.StatusCode = 404
  }
  $ctx.Response.Close()
}
