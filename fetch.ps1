$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$Url = 'https://github.com/XingYunStar/snowluma/releases/download/v2.4.2/SnowLuma-v2.4.2-win-x64.zip'
$Expect = '0912926c5e73260f35b000278a8658493fc9452f36782c32fa86f0e825bad81a'
$Zip = Join-Path $Root 'snowluma.zip'
$Extract = Join-Path $Root 'snowluma'

Write-Host '=== download ==='
if (-not (Test-Path $Zip)) {
    Invoke-WebRequest -Uri $Url -OutFile $Zip -UseBasicParsing -TimeoutSec 600
    Write-Host ('saved ' + $Zip)
} else {
    Write-Host 'zip already present'
}

Write-Host '=== verify sha256 ==='
$h = (Get-FileHash $Zip -Algorithm SHA256).Hash.ToLower()
Write-Host ('got    : ' + $h)
Write-Host ('expect : ' + $Expect)
if ($h -ne $Expect) {
    Write-Host 'SHA256 MISMATCH - refusing to extract'
    exit 1
}
Write-Host 'sha256 OK'

Write-Host '=== extract ==='
if (Test-Path $Extract) { Remove-Item $Extract -Recurse -Force }
Expand-Archive -Path $Zip -DestinationPath $Extract -Force

Write-Host '=== layout ==='
Get-ChildItem $Extract | Select-Object Name, Length | Format-Table -AutoSize | Out-String -Width 120 | Write-Host
Get-ChildItem (Join-Path $Extract 'native') -ErrorAction SilentlyContinue |
    Select-Object Name, Length | Format-Table -AutoSize | Out-String -Width 120 | Write-Host

Write-Host '=== sync native + node.exe into root for verify-local.ps1 ==='
$NativeSrc = Join-Path $Extract 'native'
$NativeDst = Join-Path $Root 'native'
if (Test-Path $NativeDst) { Remove-Item $NativeDst -Recurse -Force }
Copy-Item $NativeSrc $NativeDst -Recurse -Force
Copy-Item (Join-Path $Extract 'node.exe') (Join-Path $Root 'node.exe') -Force

Write-Host ''
Write-Host 'READY. Now run:  powershell -ExecutionPolicy Bypass -File .\verify-local.ps1'
Write-Host 'Run it as Administrator for the injection test to have a chance.'