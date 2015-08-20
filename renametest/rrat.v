// CONSIDER: SHOULD COMMIT EN 2 EVER BE HIGH IF COMMIT EN 1 IS LOW (next head is committing but head isnt)
module rrat (

	input 										clock,
	input 										reset,
	
	//
	// INPUT FROM ROB STAGE
	//
	input [`ARF_IDX-1:0]						ROB_dest_reg_1,			// Arch reg at head of the rob
	input [`PRF_IDX-1:0]						ROB_PRF_reg_1,			// PRF reg at head of the rob
	input 										commit_en_1,			// Head of the rob is committing

	input [`ARF_IDX-1:0]						ROB_dest_reg_2,
	input [`PRF_IDX-1:0]						ROB_PRF_reg_2,
	input 										commit_en_2,

	//
	// OUTPUT TO RAT AND PRF
	//
	output logic [`ARF_SIZE-1:0][`PRF_IDX-1:0]	rrat_prf_out		// Mapping of ARF to PRF	

);
		
	always_ff @(posedge clock) begin
		if(reset) begin
			for (int i = 0; i < `ARF_SIZE; i++) begin
				rrat_prf_out[i] <= `SD i;
			end
		end 
		else begin
			if(commit_en_1 && (!commit_en_2 || (commit_en_2 && (ROB_dest_reg_1 != ROB_dest_reg_2))))
			// If two instructions are committing to the same dest reg, only point to most recent
				rrat_prf_out[ROB_dest_reg_1] <= `SD ROB_PRF_reg_1;
			if(commit_en_2)
				rrat_prf_out[ROB_dest_reg_2] <= `SD ROB_PRF_reg_2;	
		end
	end


endmodule