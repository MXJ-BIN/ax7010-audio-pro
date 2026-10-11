`timescale 1ns / 1ps

// Four parallel combs plus one allpass. sample_valid must stay low for at
// least one clock between pulses; the I2S frame strobe already does that.
// Echoes sit at about 42 ms, 47 ms, 53 ms and 61 ms.
module reverb_lite (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_valid,
    input  wire signed [23:0] din,
    output reg  signed [23:0] dout
);
    localparam integer D0 = 2039;
    localparam integer D1 = 2281;
    localparam integer D2 = 2591;
    localparam integer D3 = 3001;
    localparam integer DA = 277;

    (* ram_style = "block" *) reg signed [23:0] mem0 [0:D0-1];
    (* ram_style = "block" *) reg signed [23:0] mem1 [0:D1-1];
    (* ram_style = "block" *) reg signed [23:0] mem2 [0:D2-1];
    (* ram_style = "block" *) reg signed [23:0] mem3 [0:D3-1];
    (* ram_style = "distributed" *) reg signed [23:0] mema [0:DA-1];

    integer k;
    initial begin
        for (k = 0; k < D0; k = k + 1) mem0[k] = 24'sd0;
        for (k = 0; k < D1; k = k + 1) mem1[k] = 24'sd0;
        for (k = 0; k < D2; k = k + 1) mem2[k] = 24'sd0;
        for (k = 0; k < D3; k = k + 1) mem3[k] = 24'sd0;
        for (k = 0; k < DA; k = k + 1) mema[k] = 24'sd0;
    end

    reg [11:0] a0;
    reg [11:0] a1;
    reg [11:0] a2;
    reg [11:0] a3;
    reg [8:0]  aa;
    reg        phase;
    reg signed [23:0] xh;
    reg signed [23:0] rd0;
    reg signed [23:0] rd1;
    reg signed [23:0] rd2;
    reg signed [23:0] rd3;
    reg signed [23:0] rda;

    function automatic signed [23:0] clip24;
        input signed [27:0] v;
        begin
            if (v > 28'sd8388607)
                clip24 = 24'sd8388607;
            else if (v < -28'sd8388608)
                clip24 = -24'sd8388608;
            else
                clip24 = v[23:0];
        end
    endfunction

    function automatic signed [23:0] store;
        input signed [23:0] x;
        input signed [23:0] delayed;
        reg signed [27:0] s;
        begin
            // x + 0.625 * delayed
            s     = x;
            s     = s + (delayed >>> 1);
            s     = s + (delayed >>> 3);
            store = clip24(s);
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            phase <= 1'b0;
            a0    <= 12'd0;
            a1    <= 12'd0;
            a2    <= 12'd0;
            a3    <= 12'd0;
            aa    <= 9'd0;
            xh    <= 24'sd0;
            rd0   <= 24'sd0;
            rd1   <= 24'sd0;
            rd2   <= 24'sd0;
            rd3   <= 24'sd0;
            rda   <= 24'sd0;
            dout  <= 24'sd0;
        end else if (!phase && sample_valid) begin
            phase <= 1'b1;
            xh    <= din;
            rd0   <= mem0[a0];
            rd1   <= mem1[a1];
            rd2   <= mem2[a2];
            rd3   <= mem3[a3];
            rda   <= mema[aa];
        end else if (phase) begin
            begin : writeback
                reg signed [27:0] sum;
                reg signed [23:0] comb;
                reg signed [27:0] ap_in;
                reg signed [23:0] ap_y;
                phase <= 1'b0;
                mem0[a0] <= store(xh, rd0);
                mem1[a1] <= store(xh, rd1);
                mem2[a2] <= store(xh, rd2);
                mem3[a3] <= store(xh, rd3);
                a0 <= (a0 == D0 - 1) ? 12'd0 : a0 + 12'd1;
                a1 <= (a1 == D1 - 1) ? 12'd0 : a1 + 12'd1;
                a2 <= (a2 == D2 - 1) ? 12'd0 : a2 + 12'd1;
                a3 <= (a3 == D3 - 1) ? 12'd0 : a3 + 12'd1;
                sum  = rd0;
                sum  = sum + rd1;
                sum  = sum + rd2;
                sum  = sum + rd3;
                comb = clip24(sum >>> 1);
                // allpass, g = 0.5
                ap_in    = comb;
                ap_in    = ap_in + (rda >>> 1);
                ap_y     = clip24(rda - (ap_in >>> 1));
                mema[aa] <= clip24(ap_in);
                aa       <= (aa == DA - 1) ? 9'd0 : aa + 9'd1;
                dout     <= ap_y;
            end
        end
    end
endmodule
