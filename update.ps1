# Ultimate Powers test-build updater for Company of Heroes 2 (published as update.ps1 in Voragore/ultimatepowers-builds).
# Newest build:   irm https://raw.githubusercontent.com/Voragore/ultimatepowers-builds/main/update.ps1 | iex
# A named build:  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Voragore/ultimatepowers-builds/main/update.ps1))) up7_lua
# Downloads with Windows' curl.exe (resumes a broken download), else with PowerShell; installs only a file whose
# SHA256 matches the build.
param(
    [string]$Build = "latest",
    [string]$Folder = "",
    [switch]$NoCurl
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
$curl = Join-Path $env:SystemRoot "System32\curl.exe"
$useCurl = (-not $NoCurl) -and (Test-Path $curl)

# Fetches $url into $out; a broken transfer is resumed (curl) or restarted (PowerShell), up to 5 tries.
function Get-UpFile([string]$url, [string]$out, [bool]$resume) {
    if (-not $resume -and (Test-Path $out)) { Remove-Item $out -Force }
    for ($try = 1; $try -le 5; $try++) {
        if ($useCurl) {
            $part = $resume -and (Test-Path $out)
            $cargs = @("-L", "--fail", "--silent", "--show-error", "--connect-timeout", "30", "-o", $out)
            if ($part) { $cargs += @("-C", "-") }
            & $curl @cargs $url
            if ($LASTEXITCODE -eq 0) { return $true }
            if ($LASTEXITCODE -eq 22 -and -not $part) { return $false }   # HTTP error (e.g. 404): no such build
            if (($LASTEXITCODE -eq 22 -or $LASTEXITCODE -eq 33) -and (Test-Path $out)) { Remove-Item $out -Force }   # resume refused: start fresh
        } else {
            try {
                Invoke-WebRequest $url -OutFile $out -UseBasicParsing
                return $true
            } catch {
                $code = $null
                if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
                if ($code -eq 404) { return $false }
            }
        }
        if ($try -lt 5) {
            Write-Host ("  The download broke off; trying again (" + ($try + 1) + " of 5)...") -ForegroundColor Yellow
            Start-Sleep -Seconds (2 * $try)
        }
    }
    throw ("Download failed 5 times: " + $url + ". Check the internet connection (or an antivirus web shield) and run this again.")
}

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
    if (-not (Get-UpFile ($base + "/build.txt") (Join-Path $tmp "build.txt") $false)) {
        Write-Host ("Build not found: " + $Build) -ForegroundColor Red
        return
    }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    return
}
$info = @(Get-Content (Join-Path $tmp "build.txt"))
$name = $info[0].Trim()
$want = $info[1].Trim().ToUpper()

if ((Test-Path $dst) -and (Get-FileHash $dst -Algorithm SHA256).Hash -eq $want) {
    Write-Host ("Already up to date: " + $name) -ForegroundColor Green
    return
}

# A part-file of the same build from a broken earlier run is resumed; anything else starts fresh.
$file = Join-Path $tmp "ultimatepowers.sga"
$mark = Join-Path $tmp "ultimatepowers.sga.build"
$resume = (Test-Path $mark) -and ((Get-Content $mark -TotalCount 1) -eq $want)
if (-not $resume -and (Test-Path $file)) { Remove-Item $file -Force }
Set-Content $mark $want -Encoding ASCII

Write-Host ("Downloading " + $name + " (about 40 MB)...")
$ok = $false
for ($round = 1; $round -le 2 -and -not $ok; $round++) {
    try {
        if (-not (Get-UpFile ($base + "/ultimatepowers.sga") $file $true)) {
            Write-Host ("Build file not found: " + $name) -ForegroundColor Red
            return
        }
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        return
    }
    $ok = ((Get-FileHash $file -Algorithm SHA256).Hash -eq $want)
    if (-not $ok) {
        Remove-Item $file -Force
        if ($round -eq 1) { Write-Host "  The download was damaged; downloading it once more..." -ForegroundColor Yellow }
    }
}
if (-not $ok) {
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
Remove-Item $file, $mark -Force
if ((Get-FileHash $dst -Algorithm SHA256).Hash -ne $want) {
    Write-Host "The installed file does not match the build. Run this again." -ForegroundColor Red
    return
}
Write-Host ("Installed " + $name + ". Start Company of Heroes 2 to play it.") -ForegroundColor Green
