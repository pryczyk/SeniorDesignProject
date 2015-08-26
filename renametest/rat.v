
module rat (

	input 								clock,
	input 								reset,
	
	//
	// INPUT FROM ID STAGE
	//
	input [`ARF_IDX-1:0] 				id_rega_1,
	input [`ARF_IDX-1:0] 				id_regb_1,
	input [`ARF_IDX-1:0]				id_dest_reg_1,
	input        						id_valid_inst_1,

	input [`ARF_IDX-1:0] 				id_rega_2,
	input [`ARF_IDX-1:0] 				id_regb_2,
	input [`ARF_IDX-1:0]				id_dest_reg_2,
	input        						id_valid_inst_2,

	//
	// INPUT FROM RRAT
	//
	input [`ARF_SIZE-1:0][`PRF_IDX-1:0]	rrat_prf_out,	// if branch mispredict, copy RRAT into RAT

	//
	// INPUT FROM PRF
	//
	input [`PRF_SIZE-1:0]			free_reg_1,
	input [`PRF_SIZE-1:0]			free_reg_2,

	//
	// INPUT FROM ROB
	//
	input 								flush,

	//
	// OUTPUT TO RS
	//
	output logic [`PRF_SIZE-1:0]	RS_rega_1,	
	output logic [`PRF_SIZE-1:0]	RS_regb_1,

	output logic [`PRF_SIZE-1:0]	RS_rega_2,
	output logic [`PRF_SIZE-1:0]	RS_regb_2,

	//
	// OUTPUT TO PRF
	//
	output logic						used_1,			// 1 if register from freelist is used
	output logic 						used_2,

	//
	// OUTPUT TO ROB
	//
	output logic [`PRF_IDX-1:0]			PRF_dest_reg_1,		// PRF destination register
	output logic [`PRF_IDX-1:0]			PRF_dest_reg_2,
	output logic [`PRF_IDX-1:0]			PRF_dest_old_1,		// old PRF destination register associated with ARF
	output logic [`PRF_IDX-1:0]			PRF_dest_old_2,

	//
	// Debugging Output
	//
	 output logic [`ARF_SIZE-1:0][`PRF_IDX-1:0]	PRF_idx		// Mapping of ARF to PRF
);
	//logic [`ARF_SIZE-1:0][`PRF_IDX-1:0]	PRF_idx; 				// Mapping of ARF to PRF
	always_comb begin
		used_1 = id_valid_inst_1;
		used_2 = id_valid_inst_2;
	end

	always_ff @ (posedge clock) begin
		if (reset) begin
			for (int i = 0; i < `ARF_SIZE; i++) begin
				PRF_idx[i] <= `SD i;
			end
		end
		else if (flush) begin
			PRF_idx <= `SD rrat_prf_out;
		end
		else begin
			RS_rega_1 				<= `SD PRF_idx[id_rega_1];
			RS_regb_1 				<= `SD PRF_idx[id_regb_1];
			if ((id_dest_reg_1 ==  id_rega_2 ) && id_valid_inst_1) 
			// if later inst uses dest reg of earlier valid inst as operand
				RS_rega_2 <= `SD free_reg_1;
			else
				RS_rega_2 				<= `SD PRF_idx[id_rega_2];
			if ((id_dest_reg_1 ==  id_regb_2) && id_valid_inst_1)
				RS_regb_2 <= `SD free_reg_1;
			else
				RS_regb_2 				<= `SD PRF_idx[id_regb_2]; 
			if ((id_dest_reg_1 == id_dest_reg_2) && id_valid_inst_1 && id_valid_inst_2) begin 
				// if two instructions write to the same reg, only hold later inst
				PRF_idx[id_dest_reg_2] 	<= `SD free_reg_2;
				PRF_dest_reg_1 			<= `SD free_reg_1;
				PRF_dest_reg_2			<= `SD free_reg_2;
				PRF_dest_old_1			<= `SD PRF_idx[id_dest_reg_1];
				PRF_dest_old_2			<= `SD free_reg_1;
			end
			else begin
				if (id_valid_inst_1) begin
					PRF_dest_old_1			<= `SD PRF_idx[id_dest_reg_1];
					PRF_idx[id_dest_reg_1] 	<= `SD free_reg_1;
					PRF_dest_reg_1			<= `SD free_reg_1;
				end	
				if (id_valid_inst_2) begin
					if(id_valid_inst_1) begin
						PRF_dest_old_2			<= `SD PRF_idx[id_dest_reg_2];
						PRF_idx[id_dest_reg_2] 	<= `SD free_reg_2;
						PRF_dest_reg_2			<= `SD free_reg_2;
					end
					else begin // If inst 2 is valid and inst 1 is not, use free reg 1 because it is lower.
						PRF_dest_old_2			<= `SD PRF_idx[id_dest_reg_2];
						PRF_idx[id_dest_reg_2] <= `SD free_reg_1;
						PRF_dest_reg_2			<= `SD free_reg_1;
					end	
				end	
			end
		end
	end

endmodule
