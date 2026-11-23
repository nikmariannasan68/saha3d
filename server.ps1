# САХА 3D — локальный веб-сервер без установки программ (PowerShell + HttpListener)
$ErrorActionPreference = 'Stop'
$root = (Split-Path -Parent $MyInvocation.MyCommand.Path).TrimEnd('\') + '\'
$mime = @{
  '.html'='text/html; charset=utf-8'; '.js'='application/javascript; charset=utf-8'; '.mjs'='application/javascript; charset=utf-8';
  '.css'='text/css; charset=utf-8'; '.json'='application/json'; '.geojson'='application/json'; '.md'='text/plain; charset=utf-8';
  '.png'='image/png'; '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.svg'='image/svg+xml'; '.glb'='model/gltf-binary'; '.gltf'='model/gltf+json'
}
$listener = $null
foreach ($p in 8765, 8766, 8767, 8780, 8790) {
  try { $l = New-Object System.Net.HttpListener; $l.Prefixes.Add("http://localhost:$p/"); $l.Start(); $listener = $l; $port = $p; break } catch { }
}
if (-not $listener) { Write-Host 'Не удалось открыть порт. Закройте другие копии сервера и попробуйте снова.'; Read-Host 'Enter — выход'; exit 1 }
$url = "http://localhost:$port/"
Write-Host ''
Write-Host '  САХА 3D — Живая карта Якутии' -ForegroundColor Yellow
Write-Host "  Атлас открыт: $url" -ForegroundColor Cyan
Write-Host '  Не закрывайте это окно, пока пользуетесь атласом. Закрыть окно = остановить сервер.'
Write-Host ''
Start-Process $url
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  try {
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    # Сохранение снимка геоданных: POST /__save/data/....json — только со страницы этого же сервера
    if ($ctx.Request.HttpMethod -eq 'POST' -and $rel.StartsWith('__save/')) {
      $target = $rel.Substring(7)
      $origin = $ctx.Request.Headers['Origin']
      $out = [IO.Path]::GetFullPath((Join-Path $root $target))
      if (($origin -and $origin -ne "http://localhost:$port") -or ($target -notmatch '^data/[A-Za-z0-9_\-/]+\.json$') -or -not $out.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        $ctx.Response.StatusCode = 403
      } else {
        [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out))
        $ms = New-Object IO.MemoryStream; $ctx.Request.InputStream.CopyTo($ms)
        [IO.File]::WriteAllBytes($out, $ms.ToArray())
        Write-Host "  сохранено: $target ($([math]::Round($ms.Length / 1024)) КБ)"
        $ctx.Response.StatusCode = 200
      }
      continue
    }
    if ($rel -eq '') { $rel = 'index.html' }
    $file = [IO.Path]::GetFullPath((Join-Path $root $rel))
    if ($file.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $file -PathType Leaf)) {
      $bytes = [IO.File]::ReadAllBytes($file)
      $ext = [IO.Path]::GetExtension($file).ToLower()
      $ctx.Response.ContentType = $(if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' })
      $ctx.Response.Headers.Add('Cache-Control', 'no-cache')
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else { $ctx.Response.StatusCode = 404 }
  } catch { try { $ctx.Response.StatusCode = 500 } catch { } }
  finally { try { $ctx.Response.Close() } catch { } }
}
