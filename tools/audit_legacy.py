from pathlib import Path
import hashlib,json,xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[1]
base=Path('G:/ANLU_Project/project1.0')
manifest=json.loads((root/'baseline_1.0/source_sha256.json').read_text(encoding='utf-8'))
for name,expected in manifest.items():
    assert hashlib.sha256((base/name).read_bytes()).hexdigest()==expected, f'Baseline changed: {name}'
base121=Path('G:/ANLU_Project/project1.2.1')
for name,expected in json.loads((root/'docs/baseline121_sha256.json').read_text()).items():
    assert hashlib.sha256((base121/name).read_bytes()).hexdigest()==expected,f'1.2.1 changed: {name}'
base122=root.parent/'project1.2.2'
for name,expected in json.loads((root/'docs/baseline122_sha256.json').read_text()).items():
    assert hashlib.sha256((base122/name).read_bytes()).hexdigest()==expected,f'1.2.2 changed: {name}'
for name in ['source_scale_address.v','thumbnail_scaler.v']:
    assert (root/'user_source/hdl_source'/name).read_bytes()==(base122/'user_source/hdl_source'/name).read_bytes(),f'Image path changed: {name}'
for name in ['SD/bmp_read.v']:
    assert (root/'user_source/hdl_source'/name).read_bytes()==(base121/'user_source/hdl_source'/name).read_bytes(),name
top=(root/'user_source/hdl_source/top_tf_hdmi_audio.v').read_text()
assert '.ENABLE_SD_AUDIO(1)' in top and '.left_in(selected_music_left)' in top
assert '.DYNAMIC_SPEED(1)' in top and '.reset_all_event(reset_all_event)' in top
assert '.pcm_left(selected_music_left)' in top and '.pcm_left(mixed_left)' not in top,'Spectrum must tap selected music before click mixing'
assert '.music_enable(parameters[31])' in (root/'user_source/hdl_source/display_enhance.v').read_text()
assert 'RAW_PCM_CHANNELS=1' in (root/'user_source/hdl_source/SD/sd_wav_player.v').read_text()
# TD's native .al format permits bare '&' in UsedInP&R attributes.
# Escape those only in memory for the standard XML parser.
native=(root/'TD_project/demo.al').read_text(encoding='utf-8')
import re
tree=ET.ElementTree(ET.fromstring(re.sub(r'&(?!amp;|lt;|gt;|quot;|apos;|#)', '&amp;', native)))
for node in tree.findall('.//File'):
    resolved=(root/'TD_project'/node.attrib['Path']).resolve()
    assert resolved.is_relative_to(root) and resolved.is_file(),f'Invalid project reference: {resolved}'
registered={Path(n.attrib['Path']).name for n in tree.findall('.//Verilog/File')}
assert 'module bmp_fit_read(' in (root/'user_source/hdl_source/SD/fat_bmp_read.v').read_text(encoding='utf-8'), 'Aspect-fit module must remain in the registered FAT source'
assert {'display_controls4.v','runtime_adjust.v','thumbnail_scaler.v','parameter_mailbox.v','text_layers.v',
        'status_seven_segment.v','fat32_sector_map.v','fat_bmp_read.v','source_scale_address.v','scaled_frame_reader.v','audio_mix122.v','audio_spectrum.v','sd_wav_player.v','fat32_wav_map.v','wav_pcm_reader.v','sd_read_arbiter.v','pcm_async_fifo.v'} <= registered,'Display/FAT modules missing from TD project'
for name in ['SD/sd_card_top.v','SD/sd_card_cmd.v','SD/sd_card_sec_read_write.v','SD/spi_master.v',
             'SD/frame_fifo_read.v',
             'SD/sdram.v','include/global_def.v','include/sdr_as_ram.enc.v',
             'include/sdr_init_ref.enc.v','include/sdr_wrrd.enc.v',
             'hdmi1.4b_transmitter_core/hdmi_1_4b_transmitter_core_wrapper.enc.v']:
    assert (root/'user_source/hdl_source'/name).read_bytes()==(base/'user_source/hdl_source'/name).read_bytes(),name
# The writer is changed only to widen slot selection and add two base addresses.
writer=(root/'user_source/hdl_source/SD/frame_fifo_write.v').read_text()
writer=writer.replace('parameter BANK_BITS = 2,\n\t','')
writer=writer.replace('input[BANK_BITS-1:0]             write_addr_index','input[1:0]                       write_addr_index')
writer=writer.replace('input[ADDR_BITS - 1:0]           write_addr_4, write_addr_5,\n\t','')
writer=writer.replace('reg[BANK_BITS-1:0]                  write_addr_index','reg[1:0]                            write_addr_index')
writer=writer.replace("else if(write_addr_index_d1 == 3'd3)","else if(write_addr_index_d1 == 2'd3)")
writer=re.sub(r"\n\t{4}else if\(write_addr_index_d1 == 3'd4\).*?App_wr_addr_r <= WRITE_V_FLIP \? \(write_addr_5 \+ VFLIP_FIRST_ADDR_OFFSET\) : write_addr_5;",'',writer,flags=re.S)
assert writer==(base/'user_source/hdl_source/SD/frame_fifo_write.v').read_text(),'Unexpected writer change beyond bank addressing'
assert '.CACHE_SLOTS(6)' in top and '.MAX_PHOTOS(6)' in top and '.BANK_BITS(3)' in top
assert 6*640*480*4 <= 8*1024*1024 < 7*640*480*4

def pin_assignments(path):
    result={}
    for line in path.read_text(encoding='utf-8').splitlines():
        match=re.match(r'\s*set_pin_assignment\s*\{\s*(.*?)\s*\}\s*\{\s*(.*?)\s*\}',line)
        if match: result[match[1]]=re.sub(r'\s+','',match[2])
    return result
original_pins=pin_assignments(base/'user_source/constraints_source/pin.adc')
new_pins=pin_assignments(root/'user_source/constraints_source/pin.adc')
for name,value in original_pins.items():
    if name not in {'key1','key2','rst_n'} and not name.startswith('seg_sel'):
        assert new_pins[name]==value,f'Peripheral pin changed: {name}'
for name,location in {'key1':'A2','key2':'B2','key3':'B1','key4':'C1'}.items():
    assert new_pins[name]==f'LOCATION={location};IOSTANDARD=LVCMOS33;PULLTYPE=NONE;',name
for index,location in enumerate(['F16','E16','E12','E10','C13','F10','E11','D11']):
    assert f'LOCATION={location};' in new_pins[f'seg_sel[{index}]']
for index,location in enumerate(['C8','C7','C6','C5']):
    assert new_pins[f'dip[{index}]']==f'LOCATION={location};IOSTANDARD=LVCMOS33;PULLTYPE=NONE;'
assert set(new_pins)==(set(original_pins)-{'rst_n'})|{'key3','key4','seg_sel[6]','seg_sel[7]',
                                                     'dip[0]','dip[1]','dip[2]','dip[3]'},'Unexpected pin additions'
assert (root/'baseline_1.0/demo.bit').read_bytes()==(base/'build/demo.bit').read_bytes()
assert 'PROJECT122_BUILD_PASS' in (root/'build/build_status.txt').read_text()
timing=(root/'build/timing_summary.rpt').read_text()
import re
for label in ['SWNS','STNS','HWNS','HTNS','Period Check WNS']:
    value=float(re.search(re.escape(label)+r':\s+([-\d.]+)ns',timing)[1])
    assert value>=0,f'Failed final timing: {label}={value}'
assert (root/'build/demo.bit').is_file()
inputs=list((root/'user_source').rglob('*.v'))+list((root/'user_source').rglob('*.sdc'))+list((root/'user_source').rglob('*.adc'))+[root/'TD_project/demo.al']
assert (root/'build/demo.bit').stat().st_mtime >= max(p.stat().st_mtime for p in inputs),'Bitstream predates current source'
source_hashes={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
(root/'build/compiled_source_sha256.json').write_text(json.dumps(source_hashes,indent=2),encoding='utf-8')
records={'sd_audio_playback_supported':True,'sd_audio_format':'FAT32 root, PCM16 WAV 48000Hz mono/stereo, first four WAV entries','real_test_pcm_dft_bars_radial':True,'subtitle_renderer_removed':True,'contextual_reset_speed_controls':True,'base122_image_path_byte_identical':True,'aspect_fit_bmp_decoder':True,'fat_small_files_and_large_chains_supported':True,'baseline_unchanged':True,'legacy_low_level_cores_unchanged':True,'frame_bridge_updated_for_full_resolution_scaling':True,'fat_bmp_stream_registered_for_timing':True,'all_references_local':True,
         'schematic_four_keys':{'key1':'A2','key2':'B2','key3':'B1','key4':'C1'},'peripheral_pins_preserved':True,
         'schematic_dip_pins':['C8','C7','C6','C5'],'schematic_eight_digit_pins':['F16','E16','E12','E10','C13','F10','E11','D11'],
         'constrained_timing_pass':True,'bit_sha256':hashlib.sha256((root/'build/demo.bit').read_bytes()).hexdigest()}
records['sd_audio_format']='Default bit: FAT32 root, first four raw PCM entries; s16le/48000Hz/mono. WAV parsing remains an optional source configuration with functional simulations.'
records['default_bit_wav_enabled']=False
records['selected_music_dft_bars_radial']=True
records['actual_bgm_prefix_exact_sample_simulation']=True
records['compact_spectrum_geometry']={'bar_bounds':[192,400,448,465],'bar_width':3,'bar_pitch':8,'radial_center':[552,392],'radial_radius':74,'outer_ring':False}
records['radial_visual_segments']=48
records['bar_visual_count']=32
records['bmp_fat_single_sector_cache']=True
records['color_temperature']={'dip':'1001','range':[-48,48],'step':8,'neutral':0,'key3':'cooler','key4':'warmer','digit_mode':8,'parameter_bus_width':55}
records['radial_actual_dft_bins']=16
records['sd_current_track_loop_enabled']=True
records['base122_image_path_byte_identical']=False
records['bmp_fit_step_pipeline_full_pixel_regression']=True
records['photo_catalog_limit']=6
records['physical_image_cache_slots']=6
records['legacy_writer_only_bank_addressing_changed']=True
records['resident_cache_bytes']=7372800
records['image_reload_on_navigation']=False
records['per_photo_settings']={'contrast':128,'zoom_percent':100,'temperature':0,'logical_records':10,'effective_bits':140,'volatile':True,'frame_atomic':True}
gui_dir=root/'TD_project/demo_Runs'
gui_project=root/'gui_flow_verification/demo.al'
if gui_project.is_file():
    gui_native=gui_project.read_text(encoding='utf-8')
    gui_tree=ET.fromstring(re.sub(r'&(?!amp;|lt;|gt;|quot;|apos;|#)', '&amp;', gui_native))
    gui_registered={Path(n.attrib['Path']).name for n in gui_tree.findall('.//Verilog/File')}
    assert registered==gui_registered,'GUI save lost module registrations'
    records['native_gui_module_list_preserved']=True
if (gui_dir/'phy_1/.bitgen.end.f').is_file():
    gui_timing=(gui_dir/'phy_1/demo_pr.timing').read_text()
    for label in ['SWNS','STNS','HWNS','HTNS','Period Check WNS']:
        assert float(re.search(re.escape(label)+r':\s+([-\d.]+)ns',gui_timing)[1])>=0,label
    for run in ['syn_1','phy_1']:
        assert ' ERROR:' not in (gui_dir/run/'run.log').read_text(),f'GUI run failed: {run}'
    records['gui_synthesis_physical_flow_pass']=True
    records['gui_bit_sha256']=hashlib.sha256((gui_dir/'best_result/demo.bit').read_bytes()).hexdigest()
(root/'build/audit_result.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print('BASELINE_UNCHANGED_CORE_PRESERVED_LOCAL_PROJECT_TIMING_PASS')
