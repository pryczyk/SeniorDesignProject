module prf(

	input clock,
	input reset,

	//
	// INPUTS FROM CDB
	//
	input [63:0]								CDB_value_1,
	input [`PRF_IDX-1:0]						CDB_tag_1,
	input 									 	CDB_en_1,

	input [63:0]								CDB_value_2,
	input [`PRF_IDX-1:0]						CDB_tag_2,
	input 									 	CDB_en_2,
	//
	// INPUTS FROM RAT
	//	
	input 										used_1,
	input 										used_2,

	//
	// INPUTS FROM ROB
	//
	input [`PRF_IDX-1:0]						PRF_old_1, 			// PRF to be freed
	input 										PRF_old_valid_1, 

	input [`PRF_IDX-1:0]						PRF_old_2, 	
	input 										PRF_old_valid_2, 
	input 										flush,
	
	//
	// INPUTS FROM RRAT
	//
	input [`ARF_SIZE-1:0][`PRF_IDX-1:0]			rrat_prf_out,	// Mapping of ARCH to PR's (for flushes)
	
	//
	// OUTPUTS TO RS
	//
	output logic [`PRF_SIZE-1:0][63:0]			PRF_values_out,
	output logic [`PRF_SIZE-1:0]				PRF_valid_out,
	
	//
	// OUTPUTS TO RAT
	//
	output logic [`PRF_IDX-1:0]					free_reg_1,
	output logic [`PRF_IDX-1:0]					free_reg_2,
	
	// Debugging output
	output logic [`PRF_SIZE-1:0]				PRF_free
);

	logic free_reg_valid_1; //May not need these values assuming we never run out of PRF's
	logic free_reg_valid_2;	
	logic free_reg_found_1, free_reg_found_2;
	logic [`PRF_SIZE-1:0] PRF_free_flush, PRF_valid_flush;

	//
	// PRIORITY SELECTOR of two free physical regs
	// priority is given to two lowest index free regs
	//
	always_comb begin

		free_reg_1 = `PRF_IDX'b0;
		free_reg_2 = `PRF_IDX'b0;
		free_reg_valid_1 = 1'b0;
		free_reg_valid_2 = 1'b0;
		for(int i=0;i<`PRF_SIZE;i++) begin
			if(PRF_free[i]) begin // && i!= free_reg_1 && i != free_reg_2) begin
				if(!free_reg_valid_1) begin
					free_reg_1 = i;
					free_reg_valid_1 = 1'b1;
				end // reg_found_1
				else if(!free_reg_valid_2) begin
					free_reg_2 = i;
					free_reg_valid_2 = 1'b1;
					break;
				end // reg_found_2
			end // reg_avail
		end // for-statement

		PRF_free_flush = {`PRF_SIZE{1'b1}};
		PRF_valid_flush = {`PRF_SIZE{1'b0}};
		for(int i = 0; i<`ARF_SIZE; i++) begin
			PRF_free_flush[rrat_prf_out[i]] = 1'b0;
			PRF_valid_flush[rrat_prf_out[i]] = PRF_valid_out[rrat_prf_out[i]];
		end	

	end // always_comb

	always_ff @ (posedge clock) begin
		if (reset) begin
			PRF_free 		<= `SD {{`PRF_SIZE-`ARF_SIZE{1'b1}}, `ARF_SIZE'b0};
			PRF_valid_out 	<= `SD {`PRF_SIZE{1'b0}};
			PRF_values_out 	<= `SD {`PRF_SIZE{64'b0}};
		end
		else begin
			if(CDB_en_1) begin
				PRF_values_out[CDB_tag_1]	<= `SD CDB_value_1;
				PRF_valid_out[CDB_tag_1]	<= `SD 1'b1;
			end
			if(CDB_en_2) begin
				PRF_values_out[CDB_tag_2]	<= `SD CDB_value_2;
				PRF_valid_out[CDB_tag_2]	<= `SD 1'b1;
			end
			if(flush) begin		
				PRF_free 		<= `SD PRF_free_flush;
				PRF_valid_out 	<= `SD PRF_valid_flush;
			end	
			else begin
				if (used_1)
					PRF_free[free_reg_1] 			<= `SD 1'b0;
				if (used_2) begin
					if(used_1)
						PRF_free[free_reg_2] 		<= `SD 1'b0;
					else 
						PRF_free[free_reg_1] 		<= `SD 1'b0;
				end
				if (PRF_old_valid_1) begin
					PRF_free[PRF_old_1]			<= `SD 1'b1;
					PRF_valid_out[PRF_old_1]	<= `SD 1'b0;
				end
				if (PRF_old_valid_2) begin
					PRF_free[PRF_old_2] 		<= `SD 1'b1;
					PRF_valid_out[PRF_old_2]	<= `SD 1'b0;
				end
			end	
		end
	end
	
endmodule