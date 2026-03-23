module texture_mem (
    input clk,
    input write_rst,
    write_data,
    write_clock,
    input [12:0] bank0_raddr,
    output [3:0] bank0_rdata,
    input [12:0] bank1_raddr,
    output [3:0] bank1_rdata
);
    reg [12:0] write_address;
    reg [ 7:0] write_sr;
    reg [ 7:0] write_strobe;
    reg [ 2:0] write_bit;

    reg [12:0] raddr0_delay, raddr1_delay;
    always @(posedge clk) begin
        raddr0_delay <= bank0_raddr;
        raddr1_delay <= bank1_raddr;
    end

    wire [63:0] bram_rdata;
    assign bank0_rdata = bram_rdata[(8*raddr0_delay[12:11]+4*raddr0_delay[0])+:4];
    assign bank1_rdata = bram_rdata[(32+8*raddr1_delay[12:11]+4*raddr1_delay[0])+:4];

    reg [2:0] wclk_samp, wdat_samp;
    reg [2:0] write_state;
    reg write_go;

    always @(posedge clk) begin
        if (write_rst) begin
            write_bit <= 3'b0;
            wclk_samp <= 3'b0;
            write_go  <= 1'b0;
        end else begin
            wclk_samp <= {wclk_samp[1:0], write_clock};
            wdat_samp <= {wdat_samp[1:0], write_data};
            write_go  <= 1'b0;
            if (wclk_samp[2] ^ wclk_samp[1]) begin
                // write_sr <= {write_sr[6:0], wdat_samp[2]};
                write_sr[7-write_bit] <= wdat_samp[2];
                if (write_bit == 7) begin
                    write_go  <= 1'b1;
                    write_bit <= 0;
                end else begin
                    write_bit <= write_bit + 1'b1;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (write_rst) begin
            write_state   <= 'b000;
            write_strobe  <= 'b0;
            write_address <= 'b0;
        end else begin
            case (write_state)
                3'b000: begin
                    if (write_go) write_state <= 3'b001;
                    write_strobe <= 8'b0;
                end
                3'b001: begin
                    write_strobe[write_address[12:10]] <= 1'b1;
                    write_state <= 3'b010;
                end
                3'b010: begin
                    write_state <= 3'b011;
                end
                3'b011: begin
                    write_strobe <= 8'b0;
                    write_state  <= 3'b100;
                end
                3'b100: begin
                    write_state <= 3'b101;
                end
                3'b101: begin
                    write_address <= write_address + 1'b1;
                    write_state   <= 3'b000;
                end
                default: write_state <= 3'b000;
            endcase
        end
    end

    generate
        genvar i;
        for (i = 0; i < 8; i = i + 1'b1) begin : ram_array
            wire [31:0] rdata;
            bram #(
                .LOC(i),
                .IN_REG(1'b1),
                .OUT_REG(1'b1)
            ) bram_i (
                .clk(clk),
                .waddr(write_address[7:0]),
                .raddr((i >= 4) ? bank1_raddr[8:1] : bank0_raddr[8:1]),
                .cfg(8'b00100101),
                .wdata({
                    6'b0,
                    ((i >= 4) ? bank1_raddr[10:9] : bank0_raddr[10:9]),
                    3'b0,
                    write_strobe[i],
                    2'b0,
                    write_address[9:8],
                    8'b0,
                    write_sr
                }),
                .rdata(rdata)
            );
            assign bram_rdata[8*i+:8] = rdata[7:0];
        end
    endgenerate

endmodule

