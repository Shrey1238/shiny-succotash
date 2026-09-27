// Arithmetic/logic unit. Also produces the equality flag used by beq.
module alu (
	input  cpu_pkg::instr_type_e instr_type_i,
	input  logic [31:0] operand_a_i,
	input  logic [31:0] operand_b_i,

	output logic [31:0] result_o,
	output logic        equal_o
);

	import cpu_pkg::*;

	assign equal_o = (operand_a_i == operand_b_i);

	always_comb begin
		case (instr_type_i)
			ADD, ADDI, LOAD, STORE: result_o = operand_a_i + operand_b_i;
			SUB:                    result_o = operand_a_i - operand_b_i;
			SLL:                    result_o = operand_a_i << operand_b_i[4:0];
			SRL:                    result_o = operand_a_i >> operand_b_i[4:0];
			default:                result_o = '0;
		endcase
	end

endmodule
