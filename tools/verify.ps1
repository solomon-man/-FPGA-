param([switch]$CheckExisting,[string[]]$Only=@())
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'verify_xga.ps1') -CheckExisting:$CheckExisting -Only $Only
if(!$?) {throw 'Project 2.0 verification failed'}
