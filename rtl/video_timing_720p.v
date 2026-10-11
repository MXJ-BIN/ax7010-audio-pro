`timescale 1ns / 1ps

module video_timing_720p (
    input  wire        pixel_clk,
    input  wire        reset,
    output reg         hsync,
    output reg         vsync,
    output reg         de,
    output reg  [10:0] x,
    output reg  [9:0]  y,
    output reg  [23:0] rgb
);
    localparam H_ACTIVE = 1280;
    localparam H_FRONT  = 110;
    localparam H_SYNC   = 40;
    localparam H_BACK   = 220;
    localparam H_TOTAL  = 1650;

    localparam V_ACTIVE = 720;
    localparam V_FRONT  = 5;
    localparam V_SYNC   = 5;
    localparam V_BACK   = 20;
    localparam V_TOTAL  = 750;

    // Sync-origin coordinates: vertical edges coincide with horizontal sync.
    // Each line is SYNC -> BACK -> ACTIVE -> FRONT, positive HS/VS.
    localparam H_START = H_SYNC + H_BACK;
    localparam V_START = V_SYNC + V_BACK;
    reg [10:0] h_count;
    reg [9:0] v_count;

    always @(posedge pixel_clk) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else if (h_count == H_TOTAL - 1) begin
            h_count <= 0;
            if (v_count == V_TOTAL - 1)
                v_count <= 0;
            else
                v_count <= v_count + 1'b1;
        end else begin
            h_count <= h_count + 1'b1;
        end
    end

    always @(*) begin
        de = !reset && (h_count >= H_START) && (h_count < H_START + H_ACTIVE) &&
             (v_count >= V_START) && (v_count < V_START + V_ACTIVE);
        hsync = !reset && (h_count < H_SYNC);
        vsync = !reset && (v_count < V_SYNC);
        x = de ? h_count - H_START : 0;
        y = de ? v_count - V_START : 0;

        if (!de)
            rgb = 24'h000000;
        else if (x < 160)
            rgb = 24'hFFFFFF;
        else if (x < 320)
            rgb = 24'hFFFF00;
        else if (x < 480)
            rgb = 24'h00FFFF;
        else if (x < 640)
            rgb = 24'h00FF00;
        else if (x < 800)
            rgb = 24'hFF00FF;
        else if (x < 960)
            rgb = 24'hFF0000;
        else if (x < 1120)
            rgb = 24'h0000FF;
        else
            rgb = 24'h000000;
    end
endmodule
