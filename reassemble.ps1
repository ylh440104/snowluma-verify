$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$PartDir = './qqinstaller'
$OutExe = Join-Path $env:RUNNER_TEMP 'QQ_setup.exe'
$Expect = '5cd7c13e36b391f88b2ad272fa870d74f476135b64244844ec0ad7ac7b411b48'

Write-Host '=== reassemble ==='
$parts = Get-ChildItem $PartDir -Filter 'part_*.bin' | Sort-Object Name
Write-Host ("parts: " + $parts.Count)
$fs = [System.IO.File]::Create($OutExe)
foreach ($p in $parts) {
    $bytes = [System.IO.File]::ReadAllBytes($p.FullName)
    $fs.Write($bytes, 0, $bytes.Length)
    Write-Host ("  + " + $p.Name + " " + $bytes.Length)
}
$fs.Close()

$size = (Get-Item $OutExe).Length
$hash = (Get-FileHash $OutExe -Algorithm SHA256).Hash.ToLower()
Write-Host ("size   : " + $size)
Write-Host ("sha256 : " + $hash)
Write-Host ("expect : " + $Expect)
Write-Host ("MATCH  : " + ($hash -eq $Expect))

if ($hash -ne $Expect) { Write-Host 'HASH MISMATCH - abort'; exit 1 }
Write-Host 'REASSEMBLE OK'
