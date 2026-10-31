param([string]$TdExecutable='/workspace/volumes/v_c075/TD_Engineer/bin/run.exe',[int]$Seed=6)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
if(!(Test-Path -LiteralPath $TdExecutable)){throw "Tang Dynasty executable not found: $TdExecutable"}
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$log=Join-Path $projectRoot "build\td_$stamp.log"
$err=Join-Path $projectRoot "build\td_$stamp.err"
$status=Join-Path $projectRoot 'build\build_status.txt'
$bit=Join-Path $projectRoot 'build\demo.bit'
$env:TD_PLACE_SEED="$Seed"
$started=Get-Date
Write-Output "Building $projectRoot"
Write-Output "Log: $log"
$process=Start-Process -FilePath $TdExecutable -ArgumentList 'build/build.tcl' -WorkingDirectory $projectRoot -RedirectStandardOutput $log -RedirectStandardError $err -WindowStyle Hidden -PassThru
$process.WaitForExit()
$progress=Get-Content -LiteralPath $status -Raw
if($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $bit) -or (Get-Item -LiteralPath $bit).LastWriteTime -lt $started -or !$progress.Contains('CONSTRAINED_TIMING_PASS') -or !$progress.Contains('PROJECT20_XGA_BUILD_PASS')){
    throw "Build did not pass final timing/bitstream checks. Read $log and $err. Do not use an earlier bitstream."
}
$hash=(Get-FileHash -LiteralPath $bit -Algorithm SHA256).Hash
@{built_at=(Get-Date).ToString('o');place_seed=$Seed;log=$log;bit_sha256=$hash;timing_report='build/timing_summary.rpt'} | ConvertTo-Json | Set-Content (Join-Path $projectRoot 'build\bitstream_build.json') -Encoding UTF8
Write-Output "TIMING AND BITSTREAM PASS: $bit"
Write-Output "SHA256: $hash"
