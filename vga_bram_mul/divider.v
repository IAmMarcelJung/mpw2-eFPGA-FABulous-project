module divider(
    input clk, start,
    input [15:0] a,
    input [15:0] b,
    output reg [15:0] q
);
    // based on picorv32
    reg [15:0] quotient, dividend, quotient_msk;
    reg [30:0] divisor;
    reg running;
    always @(posedge clk) begin
        if (start) begin
            running <= 1'b1;
            dividend <= a;
            divisor <= b << 14;
            quotient <= 0;
            quotient_msk <= (1 << 14);
            if (b == 0) begin
                q <= 16'hffff;
                running <= 1'b0;
            end
        end else if (!quotient_msk && running) begin
            running <= 1'b0;
            q <= quotient;
        end else begin
            if (divisor <= dividend) begin
                dividend <= dividend - divisor;
                quotient <= quotient | quotient_msk;
            end
            divisor <= divisor >> 1;
            quotient_msk <= quotient_msk >> 1;
        end
    end
endmodule
