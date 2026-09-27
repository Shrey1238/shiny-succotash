// Execution control: sequences each instruction and drives the register
// file write port, the data SRAM port, branch resolution and the halt flag.
//
// Every instruction executes in a single cycle except lw, which takes two:
//   EXEC      - drive the dSRAM read; stall fetch so the same lw is re-presented
//   LOAD_WAIT - dSRAM data is ready; write it to rd and release the stall
module control (
	input  logic clk_i,
	input  logic rst_i,
	input  logic en_i,

	// Decoded instruction
	input  logic instr_vld_i,
	input  cpu_pkg::instr_type_e instr_type_i,
	input  logic [4:0]  rd_addr_i,
	input  logic [31:0] imm_i,
	input  logic [31:0] pc_i,

	// Datapath
	input  logic [31:0] rs1_data_i,
	input  logic [31:0] rs2_data_i,
	input  logic [31:0] alu_result_i,
	input  logic        alu_equal_i,

	// Register file write port
	output logic        rd_write_en_o,
	output logic [4:0]  rd_addr_o,
	output logic [31:0] rd_data_o,

	// Data SRAM
	output logic        dsram_en_o,
	output logic        dsram_write_en_o,
	output logic [9:0]  dsram_addr_o,
	output logic [31:0] dsram_wdata_o,
	input  logic [31:0] dsram_rdata_i,
	input  logic        dsram_rready_i,

	// Fetch control
	output logic        branch_vld_o,
	output logic [9:0]  branch_trgt_o,
	output logic        branch_taken_o,
	output logic        load_stall_o,

	output logic        halted_o
);

	import cpu_pkg::*;

	typedef enum logic {
		EXEC,
		LOAD_WAIT
	} state_e;

	state_e state_q, state_d;

	logic exec_vld;
	logic [31:0] branch_target;

	assign exec_vld      = en_i & instr_vld_i & ~halted_o;
	assign branch_target = pc_i + imm_i;

	always_comb begin
		state_d          = state_q;

		rd_write_en_o    = 1'b0;
		rd_addr_o        = rd_addr_i;
		rd_data_o        = alu_result_i;

		dsram_en_o       = 1'b0;
		dsram_write_en_o = 1'b0;
		dsram_addr_o     = alu_result_i[11:2];
		dsram_wdata_o    = rs2_data_i;

		branch_vld_o     = 1'b0;
		branch_trgt_o    = branch_target[11:2];
		branch_taken_o   = 1'b0;
		load_stall_o     = 1'b0;

		case (state_q)
			EXEC: begin
				if (exec_vld) begin
					case (instr_type_i)
						ADD, ADDI, SUB, SLL, SRL: begin
							rd_write_en_o = 1'b1;
						end

						LOAD: begin
							dsram_en_o   = 1'b1;
							load_stall_o = 1'b1;
							state_d      = LOAD_WAIT;
						end

						STORE: begin
							dsram_en_o       = 1'b1;
							dsram_write_en_o = 1'b1;
						end

						BEQ: begin
							branch_vld_o   = 1'b1;
							branch_taken_o = alu_equal_i;
						end

						default: ;
					endcase
				end
			end

			LOAD_WAIT: begin
				rd_data_o = dsram_rdata_i;
				if (dsram_rready_i) begin
					rd_write_en_o = 1'b1;
					state_d       = EXEC;
				end else begin
					load_stall_o  = 1'b1;
				end
			end

			default: state_d = EXEC;
		endcase
	end

	always_ff @(posedge clk_i) begin
		if (rst_i) begin
			state_q  <= EXEC;
			halted_o <= 1'b0;
		end else begin
			state_q <= state_d;
			if (exec_vld && state_q == EXEC && instr_type_i == EBREAK)
				halted_o <= 1'b1;
		end
	end

endmodule
