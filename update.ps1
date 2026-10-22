# Ultimate Powers test-build updater for Company of Heroes 2.
# Newest build:   irm https://raw.githubusercontent.com/Voragore/ultimatepowers-builds/main/update.ps1 | iex
# A named build:  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Voragore/ultimatepowers-builds/main/update.ps1))) up7_lua
param(
    [string]$Build = "latest",
    [string]$Folder = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$releases = "https://github.com/Voragore/ultimatepowers-builds/releases"
if ($Build -eq "latest") { $base = $releases + "/latest/download" } else { $base = $releases + "/download/" + $Build }
$game = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "My Games\Company of Heroes 2"
if ($Folder -eq "") { $Folder = Join-Path $game "mods\tuning" }
$dst = Join-Path $Folder "ultimatepowers.sga"
$keep = Join-Path (Split-Path (Split-Path $Folder)) "ultimatepowers_backup"

if (Get-Process RelicCoH2 -ErrorAction SilentlyContinue) {
    Write-Host "Company of Heroes 2 is running. Close it, then run this again." -ForegroundColor Yellow
    return
}
if (-not (Test-Path (Split-Path $Folder))) {
    Write-Host ("Mods folder not found: " + (Split-Path $Folder)) -ForegroundColor Red
    Write-Host "Start Company of Heroes 2 once, or pass your tuning folder with -Folder." -ForegroundColor Red
    return
}

$tmp = Join-Path $env:TEMP "ultimatepowers_download"
New-Item -ItemType Directory -Force $tmp | Out-Null
Write-Host "Downloading build info..."
try {
    Invoke-WebRequest ($base + "/build.txt") -OutFile (Join-Path $tmp "build.txt") -UseBasicParsing
} catch {
    Write-Host ("Build not found: " + $Build) -ForegroundColor Red
    return
}
$info = @(Get-Content (Join-Path $tmp "build.txt"))
$name = $info[0].Trim()
$want = $info[1].Trim().ToUpper()

if ((Test-Path $dst) -and (Get-FileHash $dst -Algorithm SHA256).Hash -eq $want) {
    Write-Host ("Already up to date: " + $name) -ForegroundColor Green
    return
}

Write-Host ("Downloading " + $name + " (about 40 MB)...")
$file = Join-Path $tmp "ultimatepowers.sga"
Invoke-WebRequest ($base + "/ultimatepowers.sga") -OutFile $file -UseBasicParsing
if ((Get-FileHash $file -Algorithm SHA256).Hash -ne $want) {
    Write-Host "The download is damaged (checksum mismatch). Nothing was changed; run this again." -ForegroundColor Red
    return
}

New-Item -ItemType Directory -Force $Folder | Out-Null
if (Test-Path $dst) {
    New-Item -ItemType Directory -Force $keep | Out-Null
    $copy = Join-Path $keep ("ultimatepowers_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".sga")
    Copy-Item $dst $copy
    Write-Host ("Old file kept: " + $copy)
}
Copy-Item $file $dst -Force
Remove-Item $file
if ((Get-FileHash $dst -Algorithm SHA256).Hash -ne $want) {
    Write-Host "The installed file does not match the build. Run this again." -ForegroundColor Red
    return
}
Write-Host ("Installed " + $name + ". Start Company of Heroes 2 to play it.") -ForegroundColor Green
