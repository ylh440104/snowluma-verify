$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$QqExe = 'C:\Program Files\Tencent\QQNT\QQ.exe'
$Root = $PWD
$NodeExe = Join-Path $Root 'node.exe'
$Addon = Join-Path $Root 'native\snowluma-win32-x64.node'
$Dll = Join-Path $Root 'native\snowluma-win32-x64.dll'

function Hdr($s) { Write-Host ''; Write-Host ('=' * 64); Write-Host $s; Write-Host ('=' * 64) }

Hdr 'PRECHECK'
Write-Host ("qq exe : " + (Test-Path $QqExe))
Write-Host ("node   : " + (Test-Path $NodeExe))
Write-Host ("addon  : " + (Test-Path $Addon))
Write-Host ("dll    : " + (Test-Path $Dll))
$v = (Get-Item $QqExe).VersionInfo
Write-Host ("qq ver : " + $v.FileVersion)

Hdr 'LAUNCH QQ'
$before = @(Get-Process -Name 'QQ' -ErrorAction SilentlyContinue)
Write-Host ("existing QQ procs: " + $before.Count)
if ($before.Count -eq 0) {
    $p = Start-Process -FilePath $QqExe -PassThru
    Write-Host ("started pid " + $p.Id)
}
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 3
    $procs = @(Get-Process -Name 'QQ' -ErrorAction SilentlyContinue)
    Write-Host ("t+" + (($i + 1) * 3) + "s  QQ procs=" + $procs.Count + "  " + (($procs | ForEach-Object { $_.Id }) -join ','))
    if ($procs.Count -ge 1) { break }
}

Hdr 'PROCESS DETAIL'
$procs = @(Get-Process -Name 'QQ' -ErrorAction SilentlyContinue)
if ($procs.Count -eq 0) {
    Write-Host 'QQ never started - Electron may need a desktop session'
} else {
    foreach ($p in $procs) {
        $mp = $null
        try { $mp = $p.MainModule.FileName } catch { $mp = '<denied>' }
        Write-Host ("pid=" + $p.Id + " ws=" + [math]::Round($p.WorkingSet64 / 1MB) + "MB path=" + $mp)
    }
}

Hdr 'ADDON ENUM'
if ($procs.Count -gt 0) {
    $targets = ($procs | Sort-Object StartTime | ForEach-Object { $_.Id }) -join ','
    Write-Host ("target pids: " + $targets)
    & $NodeExe (Join-Path $Root 'addon-probe.cjs') $Addon 'C:\Program Files\Tencent\QQNT\QQ.exe'
} else {
    & $NodeExe (Join-Path $Root 'addon-probe.cjs') $Addon 'C:\Program Files\Tencent\QQNT\QQ.exe'
}

Hdr 'INJECT EACH PID'
foreach ($p in $procs) {
    Write-Host ("--- injecting into pid " + $p.Id)
    $out = & $NodeExe (Join-Path $Root 'inject-one.cjs') $Addon $Dll $p.Id 2>&1
    $out | ForEach-Object { Write-Host ("  " + $_) }
}

Hdr 'SUMMARY'
$procs2 = @(Get-Process -Name 'QQ' -ErrorAction SilentlyContinue)
Write-Host ("QQ still alive: " + ($procs2.Count -gt 0) + " count=" + $procs2.Count)