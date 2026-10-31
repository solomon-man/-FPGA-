
module top(
    input                       clk,
    input                       key1,           // Previous; K1+K2 toggles autoplay
    input                       key2,           // Next
    input                       key3,           // Selected parameter decrease
    input                       key4,           // Selected parameter increase

    input [3:0]                 dip,

    // HDMI TMDS
    output                      HDMI_CLK_P,
    output                      HDMI_D2_P,
    output                      HDMI_D1_P,
    output                      HDMI_D0_P,

    // HDMI DDC
    output                      HDMI_DDC_SCL,
    inout                       HDMI_DDC_SDA,

    // TF card SPI
    output                      sd_ncs,
    output                      sd_dclk,
    output                      sd_mosi,
    input                       sd_miso
);

parameter MEM_DATA_BITS = 32;
parameter ADDR_BITS     = 21;
parameter BUSRT_BITS    = 10;
parameter FRAME_PIXELS  = 24'd307200;   // 640*480
parameter BUF0_ADDR     = 24'd0;
parameter BUF1_ADDR     = FRAME_PIXELS;
parameter BUF2_ADDR = FRAME_PIXELS*2;
parameter BUF3_ADDR = FRAME_PIXELS*3;
parameter BUF4_ADDR = FRAME_PIXELS*4;
// HD B reuses preview banks 0..2 only after their owners have drained.
parameter BUF5_ADDR = 24'd0;
parameter LEGACY_MODE = 0;
parameter OSD_ENABLE = 0;
parameter WAVE_ENABLE = 0;
parameter FADE_FRAMES = 0;
parameter BRIGHTNESS = 0;
parameter CONTRAST = 128;
wire sys_locked, video_locked;
(* syn_keep=1 *) wire hd_read_busy_mem;
wire [6:0] reader_owned_mem;
(* syn_preserve=1, ASYNC_REG="TRUE" *) reg [6:0] reader_owned_meta,reader_owned_sd;
always @(posedge sd_card_clk or posedge rst_sd)
 if(rst_sd)begin reader_owned_meta<=0;reader_owned_sd<=0;end
 else begin reader_owned_meta<=reader_owned_mem;reader_owned_sd<=reader_owned_meta;end
(* syn_preserve=1, ASYNC_REG="TRUE" *) reg hd_busy_meta,hd_busy_sd;
always @(posedge sd_card_clk or posedge rst_sd)
 if(rst_sd)begin hd_busy_meta<=1;hd_busy_sd<=1;end
 else begin hd_busy_meta<=hd_read_busy_mem;hd_busy_sd<=hd_busy_meta;end
wire rst_sd,rst_mem,rst_video,rst_audio,rst_serial;
wire [2:0] active_bank;
wire active_valid,memory_read_req,frame_start;
wire auto_enabled;
wire [7:0] media_error;
wire effect_hs,effect_vs,effect_de;
wire [23:0] effect_rgb;


wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;

wire sd_card_clk;
wire ext_mem_clk;
wire ext_mem_clk_sft;
wire video_clk;
wire hdmi_5x_clk;

wire hs;
wire vs;
wire de;

wire [23:0] vout_data_raw;
wire [23:0] vout_data;
wire        display_valid;


wire        video_read_req;
wire        video_read_req_ack;
wire        video_read_en;
wire [31:0] video_read_data;

wire        sd_card_write_en;
wire [31:0] sd_card_write_data;
wire        sd_card_write_req;
wire        sd_card_write_req_ack;
wire        frame_write_finish;
reg         frame_write_toggle_mem;

wire [2:0]  write_buf_idx;
wire [2:0]  disp_buf_idx;

wire App_rd_en;
wire [ADDR_BITS-1:0] App_rd_addr;
wire Sdr_rd_en;
wire [MEM_DATA_BITS-1:0] Sdr_rd_dout;
wire App_wr_en;
wire [ADDR_BITS-1:0] App_wr_addr;
wire [MEM_DATA_BITS-1:0] App_wr_din;
wire [3:0] App_wr_dm;

wire hs_0;
wire vs_0;
wire de_0;

// HDMI 1.4b 音频发射相关
wire        audio_pll_lock;
wire        audio_mclk;
wire        audio_i2s_bclk;
wire        audio_i2s_lrck;
wire        audio_i2s_dout;
wire        audio_valid;
wire [23:0] audio_left_data;
wire [23:0] audio_right_data;
wire [23:0] mixed_left,mixed_right;
wire        acr_valid;
wire [19:0] acr_cts;
wire [19:0] acr_n;

wire        axis_s_user;
wire        axis_s_valid;
wire        axis_s_last;
wire [23:0] axis_s_data;
wire        axis_s_ready;

wire        edid_trig;
wire        edid_valid;
wire [7:0]  edid_data;

wire [9:0]  tmds_ch0_data;
wire [9:0]  tmds_ch1_data;
wire [9:0]  tmds_ch2_data;
wire [9:0]  tmds_clk_data;

// 统一复位：TF 图像链路 + HDMI 音频链路
(* syn_keep=1 *) wire rst_all;
wire [3:0] menu_page;
wire signed [6:0] temperature;
wire signed [8:0] brightness;
wire [8:0] contrast;
wire [4:0] scale;
wire [1:0] transition,audio_item;
wire mute,music_enable,click_enable,visual_enable;
wire osd_enable,next_event,auto_event,prev_event;
wire [54:0] pixel_parameters;
wire [3:0] photo_index,parameter_photo;
wire [24:0] active_settings;
wire [7:0] committed_frame;
wire [54:0] image_parameters={pixel_parameters[54],active_settings[20:14],
 pixel_parameters[46:38],active_settings[13:12],pixel_parameters[35:30],active_settings[11],
 pixel_parameters[28:20],active_settings[8:0],pixel_parameters[10:8],active_settings[10:9],pixel_parameters[5:0]};
wire [2:0] music_track,music_count,music_status;
wire [23:0] sd_audio_left,sd_audio_right;
wire [23:0] selected_music_left=pixel_parameters[43:41]==0?audio_left_data:sd_audio_left;
wire [23:0] selected_music_right=pixel_parameters[43:41]==0?audio_right_data:sd_audio_right;
wire [1:0] visual_mode,speed;
wire speed_toast,reset_all_event;
wire [7:0] transition_alpha;
wire [9:0] transition_reveal;
reg auto_meta,auto_pixel;
reg [7:0] error_meta,error_pixel;
display_controls4 #(.HAS_SD_AUDIO(1),.PER_PHOTO(1)) controls(.clk(sd_card_clk),.rst(rst_sd),.key1(key1),.key2(key2),.key3(key3),.key4(key4),.dip(dip),
 .photo_index(photo_index),.parameter_photo(parameter_photo),
 .next_event(next_event),.auto_event(auto_event),.prev_event(prev_event),.page(menu_page),
 .brightness(brightness),.contrast(contrast),.scale(scale),.transition(transition),.temperature(temperature),
 .subtitle(),.osd_enable(osd_enable),.subtitle_enable(),
 .audio_item(audio_item),.mute(mute),.music_enable(music_enable),.click_enable(click_enable),.visual_enable(visual_enable),.visual_mode(visual_mode),.speed(speed),.speed_toast(speed_toast),.reset_all_event(reset_all_event),.track_count(music_count),.music_track(music_track));
parameter_mailbox #(.WIDTH(55)) pm(.source_clk(sd_card_clk),.source_rst(rst_sd),
 .source_data({menu_page[3],temperature,music_status,music_track,speed_toast,speed,scale[4:3],visual_enable,audio_item,click_enable,music_enable,mute,scale[2],brightness,contrast,menu_page[2:0],scale[1:0],transition,visual_mode,osd_enable,1'b0}),
 .clk(video_clk),.rst(rst_video),.frame_start(frame_start),.data(pixel_parameters));
always @(posedge video_clk or posedge rst_video)begin
 if(rst_video)begin auto_meta<=0;auto_pixel<=0;error_meta<=0;error_pixel<=0;end
 else begin auto_meta<=auto_enabled;auto_pixel<=auto_meta;error_meta<=media_error;error_pixel<=error_meta;end
end
reset_release rs(sd_card_clk,rst_all,rst_sd);
reset_release rm(ext_mem_clk,rst_all,rst_mem);
reset_release rv(video_clk,rst_all,rst_video);
reset_release ra(audio_mclk,rst_all,rst_audio);
reset_release rserial(hdmi_5x_clk,rst_all,rst_serial);
parameter_mailbox #(.WIDTH(8),.DEFAULT(0)) committed_return(.source_clk(video_clk),.source_rst(rst_video),
 .source_data({active_valid,active_bank,active_settings[24:21]}),.clk(sd_card_clk),.rst(rst_sd),
 .frame_start(1'b1),.data(committed_frame));
frame_commit #(.ENABLE_EFFECTS(!LEGACY_MODE),.PER_PHOTO(1),.BANK_BITS(3)) fc(.clk(video_clk),.rst(rst_video),.frame_req(video_read_req),
    .source_clk(sd_card_clk),.source_rst(rst_sd),
    .source_ready(parameter_photo==photo_index),.requested_settings({parameter_photo,temperature,scale,contrast}),
    .active_settings(active_settings),
    .requested_bank(disp_buf_idx),.requested_valid(display_valid),
    .active_bank(active_bank),.active_valid(active_valid),
    .memory_req(memory_read_req),.frame_start(frame_start),
    .transition_mode(pixel_parameters[5:4]),.alpha(transition_alpha),.reveal(transition_reveal));
// The fifth physical button is CONFIG (dedicated PROGRAM_B), not A2.
// Configuration initializes this counter. PLL locks then release each domain.
reg [4:0] power_on_count=5'd0;
always @(posedge clk) if(!(&power_on_count)) power_on_count<=power_on_count+1'b1;
assign rst_all = !(&power_on_count) | ~audio_pll_lock | ~sys_locked | ~video_locked;

// 保持你原来的 TF / SDRAM / video 时钟
sys_pll sys_pll_m0(
    .refclk     (clk),
    .clk0_out   (sd_card_clk),
    .clk1_out   (ext_mem_clk),
    .clk2_out   (ext_mem_clk_sft),
    .locked     (sys_locked),
    .reset      (1'b0)
);

video_pll video_pll_m0(
    .refclk     (clk),
    .clk0_out   (video_clk),
    .clk1_out   (hdmi_5x_clk),
    .locked     (video_locked),
    .reset      (1'b0)
);

// 复用你 I2S->HDMI 工程里的 PLL，只取 12.288MHz 音频主时钟
PLL_HDMI_AUDIO u_audio_pll(
    .refclk     (clk),
    .reset      (1'b0),
    .extlock    (audio_pll_lock),
    .clk0_out   (),
    .clk1_out   (),
    .clk2_out   (audio_mclk)
);

// mem_clk 域把 write_finish 单拍转成 toggle，供 sd_card_clk 域可靠同步
always @(posedge ext_mem_clk or posedge rst_mem) begin
    if (rst_mem)
        frame_write_toggle_mem <= 1'b0;
    else if (frame_write_finish)
        frame_write_toggle_mem <= ~frame_write_toggle_mem;
end

// ===================== TF 四图缓存与兼容分支 =====================
generate if(LEGACY_MODE) begin: legacy
assign auto_enabled=0;assign media_error=0;
assign photo_index={1'b0,disp_buf_idx};
wire [1:0] legacy_write_bank,legacy_display_bank;
assign write_buf_idx={1'b0,legacy_write_bank};
assign disp_buf_idx={1'b0,legacy_display_bank};
assign music_count=0;assign music_status=0;assign sd_audio_left=0;assign sd_audio_right=0;
sd_card_bmp_legacy #(
    .CLK_FREQ_HZ       (100_000_000),
    .SCAN_START_SECTOR (32'd0),
    .SCAN_MAX_SECTOR   (32'd131071),
    .SCAN_TARGET_COUNT (3'd4)
) sd_card_bmp_m0(
    .clk               (sd_card_clk),
    .rst               (rst_sd),
    .key_next          (key1 | ~key2),
    .key_auto          (key2 | ~key1),
    .state_code        (),
    .bmp_width         (16'd640),
    .bmp_height        (16'd480),
    .display_valid     (display_valid),

    .write_finish_toggle(frame_write_toggle_mem),
    .write_buf_idx     (legacy_write_bank),
    .disp_buf_idx      (legacy_display_bank),

    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data),
    .SD_nCS            (sd_ncs),
    .SD_DCLK           (sd_dclk),
    .SD_MOSI           (sd_mosi),
    .SD_MISO           (sd_miso)
);
end else begin: cache
sd_card_bmp #(
    .SLIDESHOW_HD(1),.PROGRESSIVE(1),.EXTERNAL_EVENTS   (1),.DYNAMIC_SPEED(1),.ENABLE_SD_AUDIO(1),.DYNAMIC_CATALOG(0),.BANK_BITS(3),.CACHE_SLOTS(4),.MAX_PHOTOS(4),.WAIT_COMMIT(1),
    .CLK_FREQ_HZ       (100_000_000),
    .SCAN_START_SECTOR (32'd0),
    .SCAN_MAX_SECTOR   (32'd131071),
    .SCAN_TARGET_COUNT (4'd4)
) sd_card_bmp_m0(
    .reader_owned(reader_owned_sd),.hd_read_busy(hd_busy_sd),
    .photo_index(photo_index),.committed_bank(committed_frame[6:4]),
    .committed_photo(committed_frame[3:0]),.committed_valid(committed_frame[7]),
    .clk               (sd_card_clk),
    .rst               (rst_sd),
    .key_next          (key1 | ~key2),
    .key_auto          (key2 | ~key1),
    .next_event        (next_event),
    .auto_event        (auto_event),
    .prev_event        (prev_event),
    .music_track(music_track),.music_play(music_enable),.music_count(music_count),.music_status(music_status),.music_error(),
    .pixel_clk(video_clk),.pixel_rst(rst_video),.audio_tick(audio_valid),
    .audio_play_pixel(pixel_parameters[31] && pixel_parameters[43:41]!=0),.sd_audio_left(sd_audio_left),.sd_audio_right(sd_audio_right),
    .speed(speed),.reset_all_event(reset_all_event),
    .fat_status        (),
    .state_code        (),
    .bmp_width         (16'd640),
    .bmp_height        (16'd480),
    .display_valid     (display_valid),

    .write_finish_toggle(frame_write_toggle_mem),
    .write_buf_idx     (write_buf_idx),
    .disp_buf_idx      (disp_buf_idx),

    .auto_enabled      (auto_enabled),
    .cached_mask       (),
    .error_code        (media_error),
    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data),
    .SD_nCS            (sd_ncs),
    .SD_DCLK           (sd_dclk),
    .SD_MOSI           (sd_mosi),
    .SD_MISO           (sd_miso)
);
end endgenerate


// ===================== 原图像时序与帧缓存 =====================
video_timing_data video_timing_data_m0(
    .video_clk         (video_clk),
    .rst               (rst_video),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0)
);

video_delay video_delay_m0(
    .video_clk         (video_clk),
    .rst               (rst_video),
    .read_en           (video_read_en),
    .read_data         (video_read_data[31:8]),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0),
    .hs_r              (hs),
    .vs_r              (vs),
    .de_r              (de),
    .vout_data         (vout_data_raw)
);

// 首图提交前黑屏；提交后一直显示当前显示缓冲区内容
assign vout_data = active_valid ? vout_data_raw : 24'd0;
display_enhance #(.OSD_ENABLE(OSD_ENABLE),.WAVE_ENABLE(WAVE_ENABLE),
    .FADE_FRAMES(FADE_FRAMES),.BRIGHTNESS(BRIGHTNESS),.CONTRAST(CONTRAST)) fx(
    .clk(video_clk),.rst(rst_video),.hs(hs),.vs(vs),.de(de),
    .display_valid(active_valid),.frame_start(frame_start),.rgb_in(vout_data),
    .bank(active_settings[24:21]),.auto_enabled(auto_pixel),.error_code(error_pixel),
    .parameters(image_parameters),.alpha(transition_alpha),.reveal(transition_reveal),
    .pcm_valid(audio_valid),.pcm_left(selected_music_left),.pcm_right(selected_music_right),
    .out_hs(effect_hs),.out_vs(effect_vs),.out_de(effect_de),.rgb_out(effect_rgb));

frame_read_write #(
    .PROGRESSIVE(1),.BANK_BITS(3),
    .WRITE_V_FLIP     (1),
    .FRAME_WIDTH      (640),
    .FRAME_HEIGHT     (480)
) frame_read_write_m0(
    .reader_owned(reader_owned_mem),.hd_read_busy(hd_read_busy_mem),
    .mem_clk           (ext_mem_clk),
    .rst               (rst_mem),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),

    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout),

    .read_clk          (video_clk),
    .read_req          (memory_read_req),
    .read_req_ack      (video_read_req_ack),
    .read_finish       (),
    .read_addr_0       (BUF0_ADDR),
    .read_addr_1       (BUF1_ADDR),
    .read_addr_2       (BUF2_ADDR),
    .read_addr_3       (BUF3_ADDR),
    .read_addr_4(BUF4_ADDR),.read_addr_5(BUF5_ADDR),
    .read_addr_index   (active_bank),
    .read_scale        (LEGACY_MODE?5'd10:active_settings[13:9]),
    .read_len          (FRAME_PIXELS),
    .read_en           (video_read_en),
    .read_data         (video_read_data),

    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_din        (App_wr_din),
    .App_wr_dm         (App_wr_dm),

    .write_clk         (sd_card_clk),
    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_finish      (frame_write_finish),
    .write_addr_0      (BUF0_ADDR),
    .write_addr_1      (BUF1_ADDR),
    .write_addr_2      (BUF2_ADDR),
    .write_addr_3      (BUF3_ADDR),
    .write_addr_4(BUF4_ADDR),.write_addr_5(BUF5_ADDR),
    .write_addr_index  (write_buf_idx),
    .write_len         ((write_buf_idx==4 || write_buf_idx==5)?21'd786432:21'd307200),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data)
);

sdram U3(
    .Clk               (ext_mem_clk),
    .Clk_sft           (ext_mem_clk_sft),
    .Rst               (rst_mem),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_dm         (App_wr_dm),
    .App_wr_din        (App_wr_din),
    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout)
);

// ===================== 音频：内部 I2S 测试音 =====================
hdmi_audio_tone_i2s_64fs #(
    .PHASE_INC (32'd39370534),
    .AMP       (24'sd2000000)
) u_hdmi_audio_tone_i2s_64fs (
    .I_mclk      (audio_mclk),
    .I_rst       (rst_audio),
    .O_i2s_BCLK  (audio_i2s_bclk),
    .O_i2s_LRCK  (audio_i2s_lrck),
    .O_i2s_DOUT  (audio_i2s_dout)
);

I2S_receiver u_I2S_receiver(
    .I_clk              (video_clk),
    .I_rst              (rst_video),
    .I_i2s_BCLK         (audio_i2s_bclk),
    .I_i2s_LRCK         (audio_i2s_lrck),
    .I_i2s_DOUT         (audio_i2s_dout),
    .O_audio_valid      (audio_valid),
    .O_audio_left_data  (audio_left_data),
    .O_audio_right_data (audio_right_data)
);

audio_mix122 #(.BANK_BITS(4)) mixer(.clk(video_clk),.rst(rst_video),.sample_valid(audio_valid),
 .left_in(selected_music_left),.right_in(selected_music_right),
 .mute(pixel_parameters[30]),.music_enable(pixel_parameters[31]),.click_enable(pixel_parameters[32]),
 .bank(active_settings[24:21]),.display_valid(active_valid),.left_out(mixed_left),.right_out(mixed_right));

audio_arc_calculate #(
    .ACR_N         (6144)
) u_audio_arc_calculate (
    .I_clk         (video_clk),
    .I_rst         (rst_video),
    .I_audio_valid (audio_valid),
    .O_acr_valid   (acr_valid),
    .O_acr_cts     (acr_cts),
    .O_acr_n       (acr_n)
);

// ===================== RGB/DE 转 AXIS 视频 =====================
video_rgb_to_axis_640x480 u_video_rgb_to_axis_640x480(
    .I_clk         (video_clk),
    .I_rst         (rst_video),
    .I_vs          (effect_vs),
    .I_de          (effect_de),
    .I_rgb         (effect_rgb),
    .O_video_user  (axis_s_user),
    .O_video_valid (axis_s_valid),
    .O_video_last  (axis_s_last),
    .O_video_data  (axis_s_data)
);

// 上电后自动打一拍，触发一次 EDID 读取
startup_pulse #(
    .CNT_MAX(20'd100000)
) u_startup_pulse (
    .I_clk   (video_clk),
    .I_rst   (rst_video),
    .O_pulse (edid_trig)
);

// ===================== 带音频的 HDMI 1.4b 发射 =====================
hdmi_1_4b_transmitter_core_wrapper #(
    .DEVICE                 ( "EG"       ),
    .HTOTAL                 ( 1344        ),
    .HSA                    ( 136         ),
    .HFP                    ( 24         ),
    .HBP                    ( 160         ),
    .HACTIVE                ( 1024        ),
    .VTOTAL                 ( 806        ),
    .VSA                    ( 6          ),
    .VFP                    ( 3         ),
    .VBP                    ( 29         ),
    .VACTIVE                ( 768        ),
    .VIDEO_VIC              ( 0          ),
    .VIDEO_TPG              ( "Disable"  ),
    .VIDEO_FORMAT           ( "RGB"      ),
    .AUDIO_SAMPLE_RATE      ( "48K"      ),
    .IIC_SCL_DIV            ( 650        )
) u_hdmi_1_4b_transmitter_core_wrapper(
    .I_pixel_clk        (video_clk),
    .I_rst              (rst_video),
    .I_edid_read_trig   (edid_trig),
    .O_edid_read_valid  (edid_valid),
    .O_edid_read_data   (edid_data),

    .I_axis_s_user      (axis_s_user),
    .I_axis_s_valid     (axis_s_valid),
    .I_axis_s_last      (axis_s_last),
    .I_axis_s_data      (axis_s_data),
    .O_axis_s_ready     (axis_s_ready),

    .I_audio_valid      (audio_valid),
    .I_audio_left_data  (mixed_left),
    .I_audio_right_data (mixed_right),
    .I_acr_valid        (acr_valid),
    .I_acr_cts          (acr_cts),
    .I_acr_n            (acr_n),

    .O_video_locked     (),
    .O_ddc_scl          (HDMI_DDC_SCL),
    .IO_ddc_sda         (HDMI_DDC_SDA),

    .O_ch0_tmds_data    (tmds_ch0_data),
    .O_ch1_tmds_data    (tmds_ch1_data),
    .O_ch2_tmds_data    (tmds_ch2_data),
    .O_clk_tmds_data    (tmds_clk_data)
);

hdmi_phy_wrapper #(
    .DEVICE ( "EG" )
) u_hdmi2phy_wrapper(
    .I_pixel_clk        (video_clk),
    .I_serial_clk       (hdmi_5x_clk),
    .I_serial_rst       (rst_serial),
    .I_rst              (rst_video),
    .I_tmds_channel_0   (tmds_ch0_data),
    .I_tmds_channel_1   (tmds_ch1_data),
    .I_tmds_channel_2   (tmds_ch2_data),
    .I_tmds_channel_clk (tmds_clk_data),
    .O_tmds_ch0_p       (HDMI_D0_P),
    .O_tmds_ch1_p       (HDMI_D1_P),
    .O_tmds_ch2_p       (HDMI_D2_P),
    .O_tmds_clk_p       (HDMI_CLK_P)
);

endmodule

