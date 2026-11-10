$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

"=== 1. im.qq.com with browser UA ==="
$uas = @(
  @{n='Win64Chrome'; v='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'},
  @{n='Win64Edge';   v='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0'}
)
foreach ($u in $uas) {
  try {
    $r = Invoke-WebRequest -Uri 'https://im.qq.com/pcqq/index.shtml' -UseBasicParsing -TimeoutSec 60 -Headers @{'User-Agent'=$u.v}
    $h = $r.Content
    $ver = [regex]::Matches($h,'v\s*(\d+\.\d+\.\d+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
    "[$($u.n)] status=$($r.StatusCode) len=$($h.Length) versions=" + ($ver -join ',')
    $exe = [regex]::Matches($h,'https?://[^"''\s\)]+\.exe')
    "[$($u.n)] exe_links=" + $exe.Count
    foreach ($e in ($exe | Select-Object -First 10)) { "  EXE: " + $e.Value }
    $cdnhost = [regex]::Matches($h,'[a-z0-9\.\-]*dldir[a-z0-9\.\-]*\.qq\.com')
    "[" + $u.n + "] cdn_hosts=" + (($cdnhost | ForEach-Object { $_.Value } | Select-Object -Unique) -join ',')
  } catch {
    "[$($u.n)] FAIL " + $_.Exception.Message
  }
}

"=== 2. QQ NT update API endpoints ==="
$apis = @(
  'https://im.qq.com/rainbow/qq/nt',
  'https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/pcQQUpdate.json',
  'https://im.qq.com/pcqq/download.shtml',
  'https://im.qq.com/rainbow/qqdown',
  'https://qq-web.cdn-go.cn/im.qq.com_new/latest/rainbow/pcQQUpdate.json'
)
foreach ($a in $apis) {
  try {
    $r = Invoke-WebRequest -Uri $a -UseBasicParsing -TimeoutSec 30 -Headers @{'User-Agent'=$uas[0].v}
    $body = $r.Content
    "OK $($r.StatusCode) len=$($body.Length) :: $a"
    "  BODY: " + ($body.Substring(0,[Math]::Min(600,$body.Length)) -replace "\s+",' ')
  } catch {
    "FAIL $a :: " + $_.Exception.Message.Substring(0,[Math]::Min(100,$_.Exception.Message.Length))
  }
}

"=== 3. winget / chocolatey availability ==="
foreach ($c in @('winget','choco','scoop')) {
  $p = Get-Command $c -ErrorAction SilentlyContinue
  if ($p) { "FOUND $c at $($p.Source)" } else { "MISSING $c" }
}

"=== 4. winget search QQ ==="
try {
  $w = winget search QQ --accept-source-agreements 2>&1 | Out-String
  $w.Substring(0,[Math]::Min(1500,$w.Length))
} catch { "WINGET_SEARCH_FAIL " + $_.Exception.Message }

"=== 5. Direct known CDN probe (corrected patterns) ==="
$probe = @(
  'https://dldir1.qq.com/qqfile/qq/QQNT/Windows/QQ_9.9.37_260103_01_x64_01.exe',
  'https://dldir1.qq.com/qqfile/qq/QQNT/Windows/QQ_9.9.37_251130_x64_01.exe',
  'https://dldir1.qq.com/qqfile/qq/QQNT/Windows/QQ_9.9.19_250916_x64_01.exe',
  'https://dldir1.qq.com/qqfile/qq/QQNT/Windows/QQ_9.7.7_250401_x64_01.exe',
  'https://dldir1.qq.com/qqfile/qq/QQNT/Windows/QQ_9.9.37_x64.exe'
)
foreach ($p in $probe) {
  try {
    $r = Invoke-WebRequest -Uri $p -Method Head -UseBasicParsing -TimeoutSec 20
    "OK $($r.StatusCode) len=$($r.Headers.'Content-Length') :: $p"
  } catch {
    "FAIL $($_.Exception.Message.Substring(0,[Math]::Min(45,$_.Exception.Message.Length))) :: $p"
  }
}