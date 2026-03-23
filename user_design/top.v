module top (
    input wire clk,
    input wire [23:0] io_in,
    output wire [23:0] io_out,
    output wire [23:0] io_oeb
);

    // running at 10MHz: divide horizontal timings by 2.5
    // Video timing generation
    localparam HVIS = 256;
    localparam HFP = HVIS + 6;
    localparam HS = HFP + 39;
    localparam HT = 320;

    localparam VVIS = 480;
    localparam VFP = VVIS + 10;
    localparam VS = VFP + 2;
    localparam VT = 525;
    //

    reg [8:0] hcnt;
    reg [9:0] vcnt;
    // reg visible;
    reg hsync, vsync;
    reg [3:0] hsync_pipe, vsync_pipe;

    reg [6:0] frame_cnt;

    always @(posedge clk) begin
        if (reset) begin
            hcnt <= 0;
            vcnt <= 0;
            frame_cnt <= 0;
            hsync <= 1'b1;
            vsync <= 1'b1;
            hsync_pipe <= 4'hf;
            vsync_pipe <= 4'hf;
        end else begin
            if (hcnt >= (HT - 1)) begin
                if (vcnt >= (VT - 1)) begin
                    frame_cnt <= frame_cnt + 1'b1;
                    vcnt <= 0;
                end else begin
                    vcnt <= vcnt + 1'b1;
                end
                hcnt <= 0;
            end else begin
                hcnt <= hcnt + 1'b1;
            end
            {hsync, hsync_pipe} <= {hsync_pipe, ~((hcnt >= HFP) && (hcnt < HS))};
            {vsync, vsync_pipe} <= {vsync_pipe, ~((vcnt >= VFP) && (vcnt < VS))};
            // visible <= (hcnt < HVIS) && (vcnt < VVIS);
        end
    end

    // Perspective transformation
    wire [3:0] road_rdata;

    reg x_sign;
    reg [6:0] x_adj;
    reg [6:0] y_adj;
    reg [9:0] vcnt_next;

    always @(posedge clk) begin
        if (reset) begin
            x_sign <= 1'b0;
            x_adj <= 7'b0;
            y_adj <= 7'b0;
            vcnt_next <= 10'b0;
        end else begin
            x_sign <= hcnt[7];
            x_adj <= hcnt[7] ? hcnt[6:0] : (127 - hcnt[6:0]);
            y_adj <= (127 - vcnt[8:2]);
            vcnt_next <= vcnt + 1'b1;
        end
    end

    wire [15:0] x_scale, y_scale;

    divider x_div (
        .clk(clk),
        .rst(reset),
        .start(hcnt == 256),
        .a(255 * 256),
        .b(vcnt_next[8:2]),
        .q(x_scale[15:0])
    );

    assign y_scale = x_scale / 4;

    wire [15:0] x0, x1;
    dsp_mul mulx0_i (
        .A({1'b0, x_adj}),
        .B(x_scale[7:0]),
        .Q(x0)
    );
    dsp_mul mulx1_i (
        .A({1'b0, x_adj}),
        .B(x_scale[15:8]),
        .Q(x1)
    );

    wire [22:0] x_out = x0 + (x1 << 8);

    wire [15:0] y0, y1;
    dsp_mul muly0_i (
        .A({1'b0, y_adj}),
        .B(y_scale[7:0]),
        .Q(y0)
    );
    dsp_mul muly1_i (
        .A({1'b0, y_adj}),
        .B(y_scale[15:8]),
        .Q(y1)
    );
    wire [22:0] y_out = y0 + (y1 << 8);

    reg [1:0] r, g, b;

    reg [6:0] x_addr;
    reg [5:0] y_addr;
    reg x_vis;

    localparam x_shift = 16, y_shift = 16;

    // Output generation
    always @(posedge clk) begin
        if (reset) begin
            x_vis <= 1'b0;
            x_addr <= 7'b0;
            y_addr <= 6'b0;
            r <= 2'b0;
            g <= 2'b0;
            b <= 2'b0;
        end else begin
            x_vis <= (x_out[22:x_shift+1] == 0) && (y_out[22:y_shift+1] == 0);
            x_addr[6] <= x_sign;
            x_addr[5:0] <= x_sign ? x_out[x_shift:x_shift-5] : (63 - x_out[x_shift:x_shift-5]);
            y_addr[5:0] <= y_out[y_shift:y_shift-5] + frame_cnt;
            if (!hcnt[8] && x_vis)
                {r, g, b} <= {
                    road_rdata[2] & road_rdata[3],
                    road_rdata[2],  // 4bit -> 6bit
                    road_rdata[1] & road_rdata[3],
                    road_rdata[1],
                    road_rdata[0] & road_rdata[3],
                    road_rdata[0]
                };
            else {r, g, b} <= 6'b0;
        end
    end

    wire [12:0] road_raddr = {y_addr, x_addr};

    assign io_out[22] = g[0];
    assign io_out[21] = g[1];
    // assign io_out[21] = 1'b0;
    assign io_out[20] = b[0];
    assign io_out[19] = b[1];
    // assign io_out[19] = 1'b1;

    assign io_out[18] = hsync;
    assign io_out[16] = vsync;

    assign io_out[3]  = r[0];
    assign io_out[4]  = r[1];

    wire reset = io_in[0];
    wire write_clock = io_in[2];
    wire write_data = io_in[1];

    // Unused pins
    assign io_out[17]   = 1'b0;
    assign io_out[23]   = 1'b0;
    assign io_out[15:5] = 'b0;


    assign io_oeb[23:3] = {21{1'b1}};
    assign io_oeb[2:0]  = {3{1'b0}};

    // Video memory

    texture_mem mem_i (
        .clk(clk),
        .write_rst(reset),
        .write_clock(write_clock),
        .write_data(write_data),
        .bank0_raddr(road_raddr),
        .bank0_rdata(road_rdata),
        .bank1_raddr()
    );

endmodule

