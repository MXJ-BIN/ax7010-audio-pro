`timescale 1ns / 1ps

module audio_hdmi (
    input  wire       pl_clk_50m,
    input wire [31:0] status,control,levels,ui,diagnostics,input wire [127:0] spectrum,
    output wire       hdmi_clk_p,
    output wire       hdmi_clk_n,
    output wire [2:0] hdmi_d_p,
    output wire [2:0] hdmi_d_n,
    output wire       hdmi_out_en
);
    wire pixel_clk;
    wire serial_clk_5x;
    wire clocks_locked;
    wire reset = ~clocks_locked;

    wire hsync;
    wire vsync;
    wire de;
    wire [10:0] x;
    wire [9:0] y;
    wire [23:0] rgb; wire [23:0] unused_rgb;
    reg [23:0] rgb_pipe=0;
    reg [1:0] de_pipe=0,hsync_pipe=0,vsync_pipe=0;
    always @(posedge pixel_clk) begin
        if(reset)begin rgb_pipe<=0;de_pipe<=0;hsync_pipe<=0;vsync_pipe<=0;end
        else begin rgb_pipe<=rgb;de_pipe<={de_pipe[0],de};hsync_pipe<={hsync_pipe[0],hsync};vsync_pipe<={vsync_pipe[0],vsync};end
    end
    wire [9:0] tmds_red;
    wire [9:0] tmds_green;
    wire [9:0] tmds_blue;
    wire [2:0] serial_data;
    wire serial_clock;

    assign hdmi_out_en = 1'b1;

    video_clock video_clock_i (
        .clk_in1(pl_clk_50m),
        .reset(1'b0),
        .clk_out1(pixel_clk),
        .clk_out2(serial_clk_5x),
        .locked(clocks_locked)
    );

    video_timing_720p timing_i (
        .pixel_clk(pixel_clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .de(de),
        .x(x),
        .y(y),
        .rgb(unused_rgb)
    );

    tmds_encoder red_encoder_i (
        .pixel_clk(pixel_clk),
        .reset(reset),
        .video_data(rgb_pipe[23:16]),
        .control_data(2'b00),
        .video_enable(de_pipe[1]),
        .tmds_data(tmds_red)
    );

    tmds_encoder green_encoder_i (
        .pixel_clk(pixel_clk),
        .reset(reset),
        .video_data(rgb_pipe[15:8]),
        .control_data(2'b00),
        .video_enable(de_pipe[1]),
        .tmds_data(tmds_green)
    );

    tmds_encoder blue_encoder_i (
        .pixel_clk(pixel_clk),
        .reset(reset),
        .video_data(rgb_pipe[7:0]),
        .control_data({vsync_pipe[1], hsync_pipe[1]}),
        .video_enable(de_pipe[1]),
        .tmds_data(tmds_blue)
    );

    tmds_serializer red_serializer_i (
        .pixel_clk(pixel_clk),
        .serial_clk_5x(serial_clk_5x),
        .reset(reset),
        .parallel_data(tmds_red),
        .serial_data(serial_data[2])
    );

    tmds_serializer green_serializer_i (
        .pixel_clk(pixel_clk),
        .serial_clk_5x(serial_clk_5x),
        .reset(reset),
        .parallel_data(tmds_green),
        .serial_data(serial_data[1])
    );

    tmds_serializer blue_serializer_i (
        .pixel_clk(pixel_clk),
        .serial_clk_5x(serial_clk_5x),
        .reset(reset),
        .parallel_data(tmds_blue),
        .serial_data(serial_data[0])
    );

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE")
    ) clock_forward_i (
        .Q(serial_clock),
        .C(pixel_clk),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(1'b0),
        .S(1'b0)
    );

    OBUFDS clock_buffer_i (
        .I(serial_clock),
        .O(hdmi_clk_p),
        .OB(hdmi_clk_n)
    );


    reg [287:0] snapshot=0;
    reg send=0;
    wire ack,received;
    wire [287:0] coherent;
    always @(posedge pl_clk_50m) begin
        if(!send && !ack)begin snapshot<={spectrum,diagnostics,ui,levels,control,status};send<=1;end
        else if(ack)send<=0;
    end
    xpm_cdc_handshake #(.WIDTH(288),.DEST_EXT_HSK(0),.DEST_SYNC_FF(4),.SRC_SYNC_FF(4)) telemetry (
        .src_clk(pl_clk_50m),.src_in(snapshot),.src_send(send),.src_rcv(ack),
        .dest_clk(pixel_clk),.dest_out(coherent),.dest_req(received),.dest_ack(1'b0));
    reg [287:0] frame_data=0;
    reg old_vsync=0;
    always @(posedge pixel_clk)begin
        old_vsync<=vsync;
        if(reset)frame_data<=0;
        else if(vsync && !old_vsync)frame_data<=coherent;
    end
    audio_dashboard panel(pixel_clk,reset,x,y,de,frame_data,rgb);

    genvar channel;
    generate
        for (channel = 0; channel < 3; channel = channel + 1) begin : gen_tmds_out
            OBUFDS data_buffer_i (
                .I(serial_data[channel]),
                .O(hdmi_d_p[channel]),
                .OB(hdmi_d_n[channel])
            );
        end
    endgenerate
endmodule
