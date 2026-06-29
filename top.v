// Top-level for the Nios V/g PoC on the Terasic MAX 10 Plus (10M50).
// Wraps the Platform Designer system (niosv_system), connects the board
// clock/reset, and wires the custom-instruction adder to the cpu's
// "add32_ci" conduit.

module top (
    input  wire clk,      // 50 MHz on-board oscillator
    input  wire reset_n   // active-low reset (KEY0)
);

    // Custom-instruction conduit wires between the CPU and custom_adder
    wire        ci_clk;
    wire        ci_reset;
    wire [31:0] ci_data0;
    wire [31:0] ci_data1;
    wire [31:0] ci_ctrl;
    wire [31:0] ci_alu_result;
    wire        ci_enable;
    wire [31:0] ci_result;
    wire        ci_done;

    niosv_system u0 (
        .clk_clk             (clk),            //      clk.clk
        .reset_reset_n       (reset_n),        //    reset.reset_n
        .add32_ci_clk        (ci_clk),         // add32_ci.clk
        .add32_ci_reset      (ci_reset),       //         .reset
        .add32_ci_data0      (ci_data0),       //         .data0
        .add32_ci_data1      (ci_data1),       //         .data1
        .add32_ci_ctrl       (ci_ctrl),        //         .ctrl
        .add32_ci_alu_result (ci_alu_result),  //         .alu_result
        .add32_ci_enable     (ci_enable),      //         .enable
        .add32_ci_result     (ci_result),      //         .result
        .add32_ci_done       (ci_done)         //         .done
    );

    custom_adder u_adder (
        .clk        (ci_clk),
        .reset      (ci_reset),
        .data0      (ci_data0),
        .data1      (ci_data1),
        .ctrl       (ci_ctrl),
        .alu_result (ci_alu_result),
        .enable     (ci_enable),
        .result     (ci_result),
        .done       (ci_done)
    );

endmodule
