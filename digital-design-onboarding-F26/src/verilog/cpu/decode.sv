// Instruction decoder: splits a raw RV32I word into its fields, classifies it
// into an instr_type_e, and produces the sign-extended immediate.
module decode (
	input  logic [31:0] instr_i,

	output cpu_pkg::instr_type_e instr_type_o,
	output logic [4:0]  rs1_addr_o,
	output logic [4:0]  rs2_addr_o,
	output logic [4:0]  rd_addr_o,
	output logic [31:0] imm_o
);

	import cpu_pkg::*;

	localparam logic [6:0] OPC_OP_IMM = 7'b0010011;
	localparam logic [6:0] OPC_OP     = 7'b0110011;
	localparam logic [6:0] OPC_LOAD   = 7'b0000011;
	localparam logic [6:0] OPC_STORE  = 7'b0100011;
	localparam logic [6:0] OPC_BRANCH = 7'b1100011;
	localparam logic [6:0] OPC_SYSTEM = 7'b1110011;

	logic [6:0] opcode;
	logic [2:0] funct3;
	logic [6:0] funct7;

	logic [31:0] imm_i;
	logic [31:0] imm_s;
	logic [31:0] imm_b;

	assign opcode     = instr_i[6:0];
	assign rd_addr_o  = instr_i[11:7];
	assign funct3     = instr_i[14:12];
	assign rs1_addr_o = instr_i[19:15];
	assign rs2_addr_o = instr_i[24:20];
	assign funct7     = instr_i[31:25];

	assign imm_i = {{20{instr_i[31]}}, instr_i[31:20]};
	assign imm_s = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
	assign imm_b = {{19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};

	always_comb begin
		instr_type_o = NOP;
		imm_o        = '0;

		case (opcode)
			OPC_OP_IMM: begin
				imm_o = imm_i;
				if (funct3 == 3'b000) instr_type_o = ADDI;
			end

			OPC_OP: begin
				case (funct3)
					3'b000: instr_type_o = funct7[5] ? SUB : ADD;
					3'b001: instr_type_o = SLL;
					3'b101: if (!funct7[5]) instr_type_o = SRL;
					default: instr_type_o = NOP;
				endcase
			end

			OPC_LOAD: begin
				imm_o = imm_i;
				if (funct3 == 3'b010) instr_type_o = LOAD;
			end

			OPC_STORE: begin
				imm_o = imm_s;
				if (funct3 == 3'b010) instr_type_o = STORE;
			end

			OPC_BRANCH: begin
				imm_o = imm_b;
				if (funct3 == 3'b000) instr_type_o = BEQ;
			end

			OPC_SYSTEM: begin
				// ebreak = 0x00100073
				if (instr_i[31:7] == 25'h0002000) instr_type_o = EBREAK;
			end

			default: instr_type_o = NOP;
		endcase
	end

endmodule
