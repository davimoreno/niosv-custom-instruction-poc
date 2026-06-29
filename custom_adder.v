// 32-bit adder exposed as a Nios V/g custom instruction (variable-latency).
// Connected to the cpu's "add32_ci" custom-instruction conduit.
//
// Protocol (variable-latency / enable-done handshake):
//   - CPU presents operands on data0/data1 and asserts 'enable'.
//   - This block latches the sum and asserts 'done' for ONE cycle, one clock
//     after 'enable' rises. 'result' is valid in that same cycle.
//   - CPU samples 'done', reads 'result', and retires the instruction.
//
// Ports (names follow the conduit):
//   data0, data1 : the two 32-bit operands (rs1, rs2)
//   ctrl         : funct selector bits (unused - single operation)
//   alu_result   : CPU ALU result passed in (unused here)
//   enable       : asserted by the CPU when the instruction issues
//   result       : 32-bit result driven back to the CPU
//   done         : "result valid" strobe driven back to the CPU

module custom_adder (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] data0,
    input  wire [31:0] data1,
    input  wire [31:0] ctrl,
    input  wire [31:0] alu_result,
    input  wire        enable,
    output reg  [31:0] result,
    output reg         done
);

    reg enable_d;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            enable_d <= 1'b0;
            done     <= 1'b0;
            result   <= 32'd0;
        end else begin
            enable_d <= enable;
            // On the rising edge of 'enable', capture the sum and strobe 'done'
            // exactly one cycle. Edge-detect keeps it a single pulse even if
            // the CPU holds 'enable' high until it sees 'done'.
            if (enable & ~enable_d) begin
                result <= data0 + data1;
                done   <= 1'b1;
            end else begin
                done   <= 1'b0;
            end
        end
    end

endmodule
