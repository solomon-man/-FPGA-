param([switch]$SkipAudit,[string[]]$Only=@())
$ErrorActionPreference = 'Stop'
$projectRoot12 = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$simExe12 = 'E:\intelFPGA\18.1\modelsim_ase\win32aloem\vsim.exe'
$pythonExe12 = 'C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$tests12 = @(
    @{ Script='test_six_photos.do'; Log='six_photos.log'; Markers=@('SIX_RESIDENT_CAP_NO_RELOAD_FORWARD_REVERSE_WRAP_AUTOPLAY_FAILURE_SHORT_CATALOG_PASS','FAT32_SIX_BMP_DIRECTORY_CHAIN_CAP_ELEVEN_FULL_PIXELS_PASS','ALL_SIX_BANK_FULL_FRAME_VFLIP_ADDRESS_PASS','SIX_BANK_4_TO_5_SETTINGS_ATOMIC_FADE_RESET_PASS','SIX_BANK_4_5_AUDIO_CLICK_MIX_PASS','SIX_BANK_REAL_FIFO_PHYSICAL_SDR_EIGHTEEN_SCALES_FULL_RGB888_PASS','TEN_PHOTO_INDEPENDENT_CONTRAST_ZOOM_TEMP_CURRENT_ALL_RESET_FRAME_ATOMIC_FADE_PASS') },
    @{ Script='test_ten_photos.do'; Log='ten_photos.log'; Markers=@('TEN_PHOTO_CAP_FORWARD_REVERSE_WRAP_EVICTION_RELOAD_ACTIVE_PROTECTION_ERROR_AUTOPLAY_PASS','TEN_PHOTO_INDEPENDENT_CONTRAST_ZOOM_TEMP_CURRENT_ALL_RESET_FRAME_ATOMIC_FADE_PASS','FAT32_TEN_BMP_DIRECTORY_CHAIN_CAP_ELEVEN_FULL_PIXELS_RELOAD_PASS') },
    @{ Script='test_temperature.do'; Log='temperature.log'; Markers=@('TEMPERATURE_ALL_STEPS_BRIGHT_CONTRAST_RGB_SATURATION_NEUTRAL_IDENTITY_PASS','TEMPERATURE_55BIT_ASYNC_MAILBOX_ATOMIC_PENDING_UPDATES_PASS') },
    @{ Script='test_fat_cache.do'; Log='fat_cache.log'; Markers=@('FAT_CACHE_IDENTICAL_BYTES_CROSS_SECTOR_EOF_PASS FAT_READS=129->2 TOTAL_READS=260->133') },
    @{ Script='test_raw_pcm.do'; Log='raw_pcm.log'; Markers=@('REAL_BGM_PCM_PREFIX_EXACT_SAMPLES_BACKPRESSURE_PASS CHANNELS=1','REAL_BGM_PCM_PREFIX_EXACT_SAMPLES_BACKPRESSURE_PASS CHANNELS=2') },
    @{ Script='test_sd_audio.do'; Log='sd_audio.log'; Markers=@('WAV_FRAGMENTED_STEREO_CHUNKS_PADDING_EXACT_PCM_PASS','WAV_SHORT_MONO_PREFILL_EOF_PASS','WAV_BOUNDS_ALIGNMENT_REJECT_PASS PARTITION=2048','SD_AUDIO_CATALOG_INVALID_RATE_SWITCH_FLUSH_BAD_CHAIN_PASS','RAW_PCM_FRAGMENTED_MONO_EXACT_SAMPLES_WAV_SWITCH_PASS PARTITION=2048','RAW_PCM_SHORT_EOF_ODD_LENGTH_REJECT_PASS','PCM_ONLY_BUILD_CATALOG_FRAGMENTED_PLAYBACK_PASS','SD_PCM_THREE_LOOPS_EXACT_SAMPLES_STOP_PASS') },
    @{ Script='test_sd_transport.do'; Log='sd_transport.log'; Markers=@('SD_ARBITER_PRIORITY_OWNERSHIP_DRAIN_TIMEOUT_PASS','PCM_ASYNC_FIFO_BACKPRESSURE_MULTI_WRAP_EXACT_STEREO_PASS') },
    @{ Script='test_blackbox.do'; Log='blackbox.log'; Markers=@('EXISTING_PROJECT_SOURCE_ASPECT_FIT_ELABORATION_PASS') },
    @{ Script='test_fit122.do'; Log='fit122.log'; Markers=@('BMP_ASPECT_FIT_FULL_PIXELS_PADDING_UP_DOWN_EXTREME_PASS','BMP_ASPECT_FIT_INVALID_GEOMETRY_PAYLOAD_REJECTED_PASS') },
    @{ Script='test_fit_fat122.do'; Log='fit_fat122.log'; Markers=@('FAT32_SMALL_PORTRAIT_DISCOVERY_FIT_PASS','RAW_SMALL_PORTRAIT_DISCOVERY_FIT_PASS') },
    @{ Script='test_spectrum.do'; Log='spectrum.log'; Markers=@('REAL_DFT_FREQUENCY_SELECTIVITY_SILENCE_FRAME_ATOMIC_BARS_RADIAL_PASS','COMPACT_SPECTRUM_THIN_BARS_ROUND_LOWER_RIGHT_BOUNDS_PASS','RADIAL_48_SEGMENTS_NO_OUTER_RING_32_BARS_SAME_WIDTH_PASS','RAM_DFT_PREVIOUS_VERSION_EXACT_ACCUMULATORS_NOISE_RESET_RESTART_PASS') },
    @{ Script='test_122.do'; Log='features122.log'; Markers=@('AUDIO_INDEPENDENT_FLAGS_MUTE_STEREO_MIX_SATURATION_COMMIT_DURATION_PASS') },
    @{ Script='test_sdr122.do'; Log='sdr122.log'; Markers=@('ENCRYPTED_SDRAM_PHYSICAL_COMMAND_EIGHTEEN_SCALES_PASS') },
    @{ Script='test_fifo122.do'; Log='fifo122.log'; Markers=@('REAL_ASYNC_FIFO_50_TO_25MHZ_EIGHTEEN_FULL_FRAMES_RGB888_PASS') },
    @{ Script='test_frame_ui.do'; Log='frame_ui.log'; Markers=@('FRAME_UI_CHORD_CONTEXT_MUSIC_DIP_DEFAULTS_ZOOM_DIGITS_TOAST_PASS','TEMPERATURE_DIP_1001_LIMITS_OSD_DIGITS_CHORD_OVERVIEW_RESET_PASS') },
    @{ Script='test_fat121.do'; Log='fat121.log'; Markers=@('FAT32_SUPERFLOPPY_FRAGMENTED_FULL_BGR_ROOT_CHAIN_PASS','FAT32_MBR_FRAGMENTED_FULL_BGR_PASS','FAT32_MULTI_SECTOR_ACTIVE_SECOND_FAT_THIRD_MBR_PARTITION_PASS','FAT32_CIRCULAR_CHAIN_REJECTED_PASS','FAT32_EARLY_EOF_REJECTED_PASS','RAW_10_COMPATIBILITY_FULL_IMAGE_PASS','FAT32_CACHE_FULL_IMAGE_EXACT_PIXELS_METADATA_READS=29 BASELINE_READS=1802') },
    @{ Script='test_features.do'; Log='features.log'; Markers=@('RUNTIME_ALL_GRAY_ALL_MENU_PARAMS_PASS','PARAMETER_ATOMIC_FRAME_CDC_PASS','SCALER_FULL_FRAME_BANK_BOUNDARY_MODES_PASS','FADE_OLD_BLACK_COMMIT_NEW_WIPE_PASS') },
    @{ Script='test_project12.do'; Log='project12_functional.log'; Markers=@('FRAME_COMMIT_RESET_KEYS_PASS','DISPLAY_IDENTITY_OSD_FADE_CONTRAST_PASS','BMP_FULL_FRAME_BGR_HEADER_OFFSET_PASS','DISPLAY_TEMPERATURE_FULL_FRAMES_WARM_COLD_NEUTRAL_PIPELINE_PASS') },
    @{ Script='test_cache.do'; Log='cache_functional.log'; Markers=@('FOUR_BANK_CACHE_COMPLETION_ERROR_SWITCH_PASS','AUTOPLAY_3_8_15_SECONDS_RESET_PASS') },
    @{ Script='test_memory.do'; Log='memory_addresses.log'; Markers=@('ALL_FOUR_BANK_FULL_FRAME_VFLIP_ADDRESS_PASS') },
    @{ Script='test_refresh.do'; Log='sdram_refresh.log'; Markers=@('SDRAM_REFRESH_PASS') },
    @{ Script='test_bmp.do'; Log='legacy_bmp.log'; Markers=@('BMP_TIMING_FUNCTIONAL_PASS') }
)
Push-Location (Join-Path $projectRoot12 'build')
try {
    foreach ($test12 in $tests12) {
        if ($Only.Count -gt 0 -and $test12.Script -notin $Only) { continue }
        & $simExe12 -c -do $test12.Script -l $test12.Log | Out-Null
        if ($LASTEXITCODE -ne 0) { throw ('Simulator failed: '+$test12.Script) }
        $logText12 = Get-Content -LiteralPath $test12.Log -Raw
        if ($logText12 -match '\*\* (Fatal|Error):' -or $logText12 -match 'Errors:\s+[1-9]') { throw ('Simulation assertion failed: '+$test12.Log) }
        foreach ($marker12 in $test12.Markers) {
            if (!$logText12.Contains($marker12)) { throw ('Missing test marker: '+$marker12) }
        }
        Write-Output ('PASS '+$test12.Script)
    }
    if (!$SkipAudit) { & $pythonExe12 -X utf8 (Join-Path $PSScriptRoot 'audit.py')
    if ($LASTEXITCODE -ne 0) { throw 'Project integrity audit failed' } }
} finally { Pop-Location }
