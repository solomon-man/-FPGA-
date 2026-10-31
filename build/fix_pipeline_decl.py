from pathlib import Path
p=Path(r'G:\ANLU_Project\digital photo frame3.0\user_source\hdl_source\display_enhance.v')
s=p.read_text().replace('wire [23:0] adjusted_q;reg [23:0] photo_q;','')
s=s.replace('reg [23:0] fx_rgb;integer f;','reg [23:0] fx_rgb;wire [23:0] adjusted_q;reg [23:0] photo_q;integer f;')
p.write_text(s)
b=p.parents[2]/'build'
for name in ['render_pipeline','adjust_pipeline','video_alignment']:
 t=b/('test_'+name+'.do');s=t.read_text().replace('vlog -sv ','vlog -sv -work work_'+name+' ').replace('vsim -novopt work.','vsim -novopt work_'+name+'.');t.write_text(s)
