param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = (Resolve-Path -LiteralPath $GodotPath).Path
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$testProfile = Join-Path ([System.IO.Path]::GetTempPath()) 'braindead-validation'

try {
    $env:APPDATA = Join-Path $testProfile 'Roaming'
    $env:LOCALAPPDATA = Join-Path $testProfile 'Local'
    New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    & $enginePath --headless --path $projectRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
    & $enginePath --headless --path $projectRoot --script res://tests/gameplay_test.gd --quit-after 1800 -- --no-save
    if ($LASTEXITCODE -ne 0) { throw 'Gameplay integration checks failed.' }
    & $enginePath --headless --path $projectRoot --script res://tests/physics_playtest.gd --fixed-fps 60 -- --no-save
    if ($LASTEXITCODE -ne 0) { throw 'Full-stage physics playtest failed.' }
}
finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
