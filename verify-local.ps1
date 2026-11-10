$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$NativeDir = Join-Path $Root 'native'
$NodeExe = Join-Path $Root 'node.exe'
$NodeAddon = Join-Path $NativeDir 'snowluma-win32-x64.node'
$DllPath = Join-Path $NativeDir 'snowluma-win32-x64.dll'

function Line($s) { Write-Host $s }
function Hdr($s) { Write-Host ''; Write-Host ('=' * 70); Write-Host $s; Write-Host ('=' * 70) }

Hdr 'SETUP'
Line ("Root       : " + $Root)
Line ("node.exe   : " + (Test-Path $NodeExe))
Line ("addon      : " + (Test-Path $NodeAddon))
Line ("dll        : " + (Test-Path $DllPath))
Line ("PS version : " + $PSVersionTable.PSVersion)
Line ("IsAdmin    : " + ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))

foreach ($f in @($NodeExe, $NodeAddon, $DllPath)) {
    if (-not (Test-Path $f)) { Write-Host ("MISSING: " + $f); exit 1 }
}

Hdr 'STEP 1  Locate QQ NT'
$Candidates = @(
    'C:\Program Files\Tencent\QQNT\QQ.exe',
    'C:\Program Files (x86)\Tencent\QQNT\QQ.exe',
    "$env:LOCALAPPDATA\Programs\Tencent\QQNT\QQ.exe",
    'D:\Program Files\Tencent\QQNT\QQ.exe'
)
$QqExe = $null
foreach ($c in $Candidates) { if (Test-Path $c) { $QqExe = $c; break } }
if (-not $QqExe) {
    $hit = Get-ChildItem 'C:\' -Recurse -Filter 'QQ.exe' -ErrorAction SilentlyContinue -Depth 6 |
           Where-Object { $_.FullName -like '*QQNT*' } | Select-Object -First 1
    if ($hit) { $QqExe = $hit.FullName }
}
if (-not $QqExe) { Line 'QQ.exe NOT FOUND - abort'; exit 2 }

Line ("QQ.exe path : " + $QqExe)
$QqVer = (Get-Item $QqExe).VersionInfo
Line ("FileVersion : " + $QqVer.FileVersion)
Line ("ProductVer  : " + $QqVer.ProductVersion)
Line ("FileDesc    : " + $QqVer.FileDescription)
$QqDir = Split-Path -Parent $QqExe
Line ("QQ dir      : " + $QqDir)

Hdr 'STEP 2  Probe payload versions on disk'
$PayloadDir = Join-Path $QqDir 'resources\app\versions'
if (Test-Path $PayloadDir) {
    Get-ChildItem $PayloadDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Line ("payload ver : " + $_.Name)
    }
} else {
    Line 'no resources\app\versions directory'
    Get-ChildItem $QqDir -Directory -ErrorAction SilentlyContinue | ForEach-Object { Line ("  dir: " + $_.Name) }
}

Hdr 'STEP 3  QQ process state'
$qqProcs = Get-Process -Name 'QQ' -ErrorAction SilentlyContinue
if ($qqProcs) {
    foreach ($p in $qqProcs) { Line ("PID " + $p.Id + "  started=" + $p.StartTime) }
} else {
    Line 'QQ not running - launching it'
    Start-Process -FilePath $QqExe
    Start-Sleep -Seconds 12
    $qqProcs = Get-Process -Name 'QQ' -ErrorAction SilentlyContinue
    foreach ($p in $qqProcs) { Line ("PID " + $p.Id + "  started=" + $p.StartTime) }
}
$MainPid = ($qqProcs | Sort-Object StartTime | Select-Object -First 1).Id
Line ("main pid candidate : " + $MainPid)

Hdr 'STEP 4  Native addon enumeration'
$probe = @'
const path = require('path');
const addonPath = process.argv[2];
const dllPath   = process.argv[3];
const targetPid = parseInt(process.argv[4], 10);

const mod = { exports: {} };
try {
  process.dlopen(mod, addonPath);
} catch (e) {
  console.log('ADDON_LOAD_FAIL ' + e.message);
  process.exit(10);
}
const addon = mod.exports;
console.log('ADDON_LOADED exports=' + Object.keys(addon).join(','));

(async () => {
  if (typeof addon.getAllMainProcessAsync === 'function') {
    try {
      const pids = await addon.getAllMainProcessAsync();
      console.log('ENUM_PIDS ' + JSON.stringify(pids));
      if (!pids || pids.length === 0) console.log('ENUM_EMPTY');
    } catch (e) {
      console.log('ENUM_FAIL ' + e.message);
    }
  } else {
    console.log('ENUM_UNSUPPORTED');
  }

  if (typeof addon.getRuntimeIntegrityAsync === 'function') {
    try {
      const r = await addon.getRuntimeIntegrityAsync();
      console.log('INTEGRITY ' + JSON.stringify(r));
    } catch (e) { console.log('INTEGRITY_FAIL ' + e.message); }
  }

  if (typeof addon.getFileHoldersAsync === 'function') {
    try {
      const r = await addon.getFileHoldersAsync(process.argv[5]);
      console.log('HOLDERS ' + JSON.stringify(r).slice(0, 400));
    } catch (e) { console.log('HOLDERS_FAIL ' + e.message); }
  }

  if (typeof addon.loadModuleManualAsync === 'function' && targetPid > 0) {
    try {
      const h = await addon.loadModuleManualAsync(targetPid, dllPath);
      console.log('INJECT_OK ' + JSON.stringify(h, (k, v) => typeof v === 'bigint' ? v.toString() : v));
    } catch (e) {
      console.log('INJECT_FAIL ' + e.message);
    }
  } else {
    console.log('INJECT_SKIPPED');
  }
  process.exit(0);
})();
'@
$probePath = Join-Path $Root '_probe.cjs'
Set-Content -Path $probePath -Value $probe -Encoding UTF8

$dbGuess = Join-Path $env:USERPROFILE 'Documents\Tencent Files'
$out = & $NodeExe $probePath $NodeAddon $DllPath $MainPid $dbGuess 2>&1
$out | ForEach-Object { Line $_ }

Hdr 'STEP 5  Pipe / socket check'
$rtDirs = @(
    (Join-Path $env:LOCALAPPDATA 'SnowLuma'),
    (Join-Path $env:APPDATA 'SnowLuma'),
    (Join-Path $env:TEMP 'snowluma')
)
foreach ($d in $rtDirs) {
    if (Test-Path $d) {
        Line ("runtime dir: " + $d)
        Get-ChildItem $d -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 30 | ForEach-Object { Line ("  " + $_.Name) }
    }
}
Get-ChildItem '\\.\pipe\' -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*snowluma*' -or $_.Name -like '*mojo*' } | Select-Object -First 20 | ForEach-Object { Line ("pipe: " + $_.Name) }

Hdr 'STEP 6  Verdict'
$enumLine = ($out | Select-String 'ENUM_PIDS' | Select-Object -First 1)
$injectLine = ($out | Select-String 'INJECT_OK|INJECT_FAIL' | Select-Object -First 1)
Line ("enum   : " + $enumLine)
Line ("inject : " + $injectLine)

if ($injectLine -match 'INJECT_OK') {
    Line 'RESULT: INJECTION COMPATIBLE'
} elseif ($injectLine -match 'INJECT_FAIL') {
    Line 'RESULT: INJECTION INCOMPATIBLE'
} else {
    Line 'RESULT: INCONCLUSIVE'
}

Line ''
Line 'Done. Copy everything above into the report.'