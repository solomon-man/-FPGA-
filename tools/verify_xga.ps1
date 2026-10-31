param([switch]$CheckExisting,[string[]]$Only=@())
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$sim='E:\intelFPGA\18.1\modelsim_ase\win32aloem\vsim.exe'
$tests=Get-Content (Join-Path $PSScriptRoot 'tests20.json') -Raw | ConvertFrom-Json
$results=@()
Push-Location (Join-Path $root 'build')
try {
 foreach($test in $tests) {
  if($Only.Count -gt 0 -and $test.name -notin $Only) {continue}
  if(!$CheckExisting) {
   foreach($fixture in $test.fixtures) {if(!(Test-Path -LiteralPath $fixture)) {throw "Missing fixture: $fixture"}}
   & $sim -c -do $test.script -l $test.log | Out-Null
   if($LASTEXITCODE -ne 0) {throw "Simulator failed: $($test.name)"}
  }
  $log=Get-Content -LiteralPath $test.log -Raw
  if($log -match '\*\* (Fatal|Error):|Errors:\s+[1-9]|Failed to open readmem|No such file or directory') {throw "Failed simulation: $($test.log)"}
  foreach($marker in $test.markers) {if(!$log.Contains($marker)) {throw "Missing PASS marker: $marker"}}
  $results+=@{test=$test.name;log=$test.log;log_sha256=(Get-FileHash $test.log -Algorithm SHA256).Hash;checked_at=(Get-Date).ToString('o')}
  Write-Output "PASS $($test.name)"
 }
 if($Only.Count -eq 0) {
  $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath 'verified_tests20.json' -Encoding UTF8
 }
} finally {Pop-Location}
