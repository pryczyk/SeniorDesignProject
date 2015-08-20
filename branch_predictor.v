// This is a module for both a local history branch predictor as well as a return address stack.  The branch predictor 
// indexes into a 32 entry BHT using the last 5 bits of the instruction PC which stores the last 4 iterations of the branch.
// These 4 iterations index into a 16 entry PHT which is a 2 bit counter (weakly/strongly taken/not taken).  The branch predictor
// is located in the fetch stage and directly updates the fetch stage's next pc value, therefore wasting no cycles between fetch and prediction.
// One downside to the predictor is that it is updated by the execute stage and considering we are executing out of order, can cause for some inacuraccy.
// The RAS operates as follows: check if either fetched instruction is a call or return.  If call: add the return address to the stack and set ras_valid to 1.
// If return and ras_valid is 1, set next PC equal to the last address on the stack and pop it off.  If there is a branch mispredict, clear the stack
// and set ras_valid to 0.
//
module branch_predictor(
	input 						clock,
	input						reset,

	input [63:0]				if_NPC_1,					// Next PC of the fetched instructions
	input [63:0]				if_NPC_2,

	input [63:0]				CDB_NPC_1,					// Next PC of the instructions on the CDB
	input [63:0]				CDB_NPC_2,

	input [31:0]				if_IR_1,					// Fetched instructions
	input [31:0]				if_IR_2,

	input						CDB_valid_inst_1,			
	input 						CDB_take_branch_1,			// Was the branch on the CDB taken
	input 						CDB_uncond_branch_1,		// Was it an unconditional branch
	input 						CDB_cond_branch_1,			// Was it a conditional branch
	input [63:0]				CDB_tar_addr_1,				// Calculated target address of the branch

	input						CDB_valid_inst_2,
	input						CDB_take_branch_2,
	input 						CDB_uncond_branch_2,
	input 						CDB_cond_branch_2,
	input [63:0]				CDB_tar_addr_2,	

	input						mispredict,					// Was there a mispredict (from head of rob)



	input						if_valid_inst_1,			// Was the fetched instruction valid
	input						if_valid_inst_2,

	//
	// Outputs to IF
	//
	output logic [63:0] 			BP_tar_addr_1_out,		// Target predicted address
	output logic					BP_predict_1_out,		// Prediction of the BP or the RAS if applicable

	output logic [63:0] 			BP_tar_addr_2_out,
	output logic					BP_predict_2_out

	// Debugging output, used for test benches
/*	output logic [`GHR_SIZE-1:0]						GHR,			
	output logic [`BTB_SIZE-1:0][(61-`BTB_IDX):0]		BTB_tags,
	output logic [`BTB_SIZE-1:0][63:0]					BTB_addr,
	output logic [`BTB_SIZE-1:0]						BTB_valid,
	output logic [`BHT_SIZE-1:0][`PHT_IDX-1:0]			BHT,
	output logic [`PHT_SIZE-1:0][1:0]					PHT  */
	);


	logic [`RAS_SIZE-1:0] [63:0]				RAS;				// Return address stack
	logic										return_1;			// Is the instruction a return
	logic										return_2;
	logic 										call_1;				// Is the instruction a call
	logic										call_2;

	logic 										RAS_valid;			// Is the RAS currently valid
	logic [`RAS_IDX-1:0]						stack_pointer;		// Pointer to  the next empty space in the stack (for returns,
																	// check stack_pointer - 1;

	logic [5:0]									opc_1;				// opcode of instruction 1
	logic [5:0]									opc_2;
	logic [1:0]									group_1;			// instruction group if instruction 1
	logic [1:0]									group_2;

	logic [63:0] 			BP_tar_addr_1;							// Target address predicted by BP
	logic					BP_predict_1;							// prediction

	logic [63:0] 			BP_tar_addr_2;
	logic					BP_predict_2;

	logic [63:0] 			ras_tar_addr_1;							// Target address predicted by RAS
	logic					ras_valid_1;							// Prediction

	logic [63:0] 			ras_tar_addr_2;
	logic					ras_valid_2;

	logic [`RAS_IDX-1:0]	next;									// used to make the RAS circular

	assign BP_tar_addr_1_out = ras_valid_1 ? ras_tar_addr_1 :		// Assign output depending on if the RAS is valid
								BP_tar_addr_1;
	assign BP_tar_addr_2_out = ras_valid_2 ? ras_tar_addr_2 :
								BP_tar_addr_2;
	assign BP_predict_1_out = (ras_valid_1 || BP_predict_1);
	assign BP_predict_2_out = (ras_valid_2 || BP_predict_2);



	assign opc_1 = if_IR_1[31:26];									// Assign opcode and group based on the instruction register
	assign opc_2 = if_IR_2[31:26];
	assign group_1 = if_IR_1[15:14];
	assign group_2 = if_IR_2[15:14];

	assign return_1 = ((opc_1 == 6'h1a) && (group_1 == 2'b10 || group_1 == 2'b11));		// Decode the instruction to see if it is a call or return
	assign return_2 = ((opc_2 == 6'h1a) && (group_2 == 2'b10 || group_2 == 2'b11));		// Our provided decoder did not check for this so we had
	assign call_1 = (opc_1 == 6'h34 || (opc_1 == 6'h1a && (group_1 == 2'b11 || group_1 == 2'b01)));		// to make one ourselves
	assign call_2 = (opc_2 == 6'h34 || (opc_2 == 6'h1a && (group_2 == 2'b11 || group_2 == 2'b01)));

	//-----------------------------------------------------------------------------------------------------------

	logic [63:0]								if_PC_1;					// Nametags for variables to make always blocks easier to read
	logic [63:0]								if_PC_2;
	logic [61-`BTB_IDX:0]						if_tag_1;
	logic [61-`BTB_IDX:0]						if_tag_2;
	logic [`BTB_IDX-1:0]						if_set_1;
	logic [`BTB_IDX-1:0]						if_set_2;
	logic [`BHT_IDX-1:0]						BHT_id_1;
	logic [`BHT_IDX-1:0]						BHT_id_2;
	logic [`PHT_IDX-1:0]						PHT_id_1;
	logic [`PHT_IDX-1:0]						PHT_id_2;

	logic [63:0]								CDB_PC_1;
	logic [63:0]								CDB_PC_2;
	logic [61-`BTB_IDX:0]						CDB_tag_1;
	logic [61-`BTB_IDX:0]						CDB_tag_2;
	logic [`BTB_IDX-1:0]						CDB_set_1;
	logic [`BTB_IDX-1:0]						CDB_set_2;
	logic [`BHT_IDX-1:0]						BHT_CDB_1;
	logic [`BHT_IDX-1:0]						BHT_CDB_2;
	logic [`PHT_IDX-1:0]						PHT_CDB_1;
	logic [`PHT_IDX-1:0]						PHT_CDB_2;					////////////////////////////////////////////////////////////////

	//logic [`GHR_SIZE-1:0]						GHR;						// Global history register (unused)
	logic [`BTB_SIZE-1:0][(63-`BTB_IDX):0]		BTB_tags;					// Branch target buffer tags
	logic [`BTB_SIZE-1:0][63:0]					BTB_addr;					// BTB target addresses
	logic [`BTB_SIZE-1:0]						BTB_valid;					
	logic [`BHT_SIZE-1:0][`PHT_IDX-1:0]			BHT;						// Branch history table
	logic [`PHT_SIZE-1:0][1:0]					PHT; 						// Pattern history table
	logic 										next_predict_1;				// combinational logic that is latched to output
	logic 										next_predict_2;

	logic 										same_set;					// checks for errors caused by 2 way superscalar (two predicted instructions
																			// could be in the same set, therefore our PHT needs to be updated twice.
	logic										same_bht;
	logic										found_1;					// Whether or not the BTB has an address prediction for the instruction.
	logic										found_2;

	assign if_PC_1 = if_NPC_1 - 4;			// This line is sort of redundant but I refused to have a branch predictor that used NPC instead of PC
	assign if_PC_2 = if_NPC_2 - 4;
	assign if_tag_1 = if_PC_1[63:(2+`BTB_IDX)];
	assign if_tag_2 = if_PC_2[63:(2+`BTB_IDX)];
	assign if_set_1 = if_PC_1[(`BTB_IDX+2):2];
	assign if_set_2 = if_PC_2[(`BTB_IDX+2):2];
	assign BHT_id_1 = if_PC_1[(`BHT_IDX+2):2];
	assign BHT_id_2 = if_PC_2[(`BHT_IDX+2):2];
	assign PHT_id_1 = BHT[BHT_id_1];
	assign PHT_id_2 = BHT[BHT_id_2];
	assign next_predict_1 = PHT[PHT_id_1] [1];
	assign next_predict_2 = PHT[PHT_id_2] [1];

	assign CDB_PC_1 = CDB_NPC_1 - 4;
	assign CDB_PC_2 = CDB_NPC_2 - 4;
	assign CDB_tag_1 = CDB_PC_1[63:(2+`BTB_IDX)];
	assign CDB_tag_2 = CDB_PC_2[63:(2+`BTB_IDX)];
	assign CDB_set_1 = CDB_PC_1[(`BTB_IDX+2):2];
	assign CDB_set_2 = CDB_PC_2[(`BTB_IDX+2):2];
	assign BHT_CDB_1 = CDB_PC_1[(`BHT_IDX+2):2];
	assign BHT_CDB_2 = CDB_PC_2[(`BHT_IDX+2):2];
	assign PHT_CDB_1 = BHT[BHT_CDB_1];
	assign PHT_CDB_2 = BHT[BHT_CDB_2];

	assign same_set = ((CDB_set_1 == CDB_set_2) && CDB_valid_inst_1 && CDB_valid_inst_2);
	assign same_bht = ((BHT_CDB_1 == BHT_CDB_2) && CDB_valid_inst_1 && CDB_valid_inst_2 && CDB_cond_branch_1 && CDB_cond_branch_2);

	assign found_1 = (BTB_tags[if_set_1] == if_tag_1) && BTB_valid[if_set_1];
	assign found_2 = (BTB_tags[if_set_2] == if_tag_2) && BTB_valid[if_set_2];

	always_comb begin
		if(if_valid_inst_1 && found_1) begin
			BP_tar_addr_1			= 		BTB_addr[if_set_1];
			if(call_1) 
				BP_predict_1 		=		1'b1;
			else
				BP_predict_1		=		next_predict_1;
			BP_tar_addr_2 			= 		64'd0;
			BP_predict_2			=		1'b0;	
		end
		else if(if_valid_inst_2 && found_2) begin
			BP_tar_addr_1			= 		64'd0;
			BP_predict_1			= 		1'b0;
			BP_tar_addr_2 			= 		BTB_addr[if_set_2];
			if(call_2)
				BP_predict_2 		= 		1'b1;
			else	
				BP_predict_2		=		next_predict_2;	
		end
		else begin
			BP_tar_addr_1			= 		64'd0;
			BP_predict_1			= 		1'b0;	
			BP_tar_addr_2 			= 		64'd0;
			BP_predict_2			=		1'b0;		
		end
	end
	
	// synopsys sync_set_reset "reset"
	always_ff @ (posedge clock) begin
		if(reset) begin
			GHR 		<=		`SD {`GHR_SIZE{1'b0}};
			BTB_tags	<=		`SD {`BTB_SIZE*(64-`BTB_IDX){1'b0}};
			BTB_addr	<=		`SD {`BTB_SIZE{64'b0}};
			BTB_valid	<=		`SD {`BTB_SIZE{1'b0}}; 
			BHT 		<=		`SD {`BHT_SIZE*`PHT_IDX{1'b0}};
			for(int i=0; i<`PHT_SIZE;i++)begin							// The following lines of code deserve recognition, on reset the pattern history
				if(i==1 || i==3 || i==7 || i==15 || i==31 || i==63)		// table resets to weakly taken (2'b01) in all positions except for locations
					PHT[i] <= `SD 2'b10;								// 1, 3, 7, 15, 31 and 63.  This is because these indices represent a string of
				else													// taken branches, thus reducing warmup time for always taken branches
					PHT[i] <= `SD 2'b01;	
			end		
		end 
		else begin
			if(CDB_valid_inst_1) begin
				if((CDB_cond_branch_1 || CDB_uncond_branch_1) && !same_set) begin
					BTB_addr[CDB_set_1]		<=		`SD CDB_tar_addr_1;
					BTB_tags[CDB_set_1]		<=		`SD CDB_tag_1;
					BTB_valid[CDB_set_1]	<=		`SD 1'b1;
				end	
				if(CDB_cond_branch_1 && !same_bht) begin
					BHT[BHT_CDB_1] 			<= 		`SD {BHT[BHT_CDB_1] [`PHT_IDX-2:0], CDB_take_branch_1}; // Update BHT
					if(CDB_take_branch_1 && (PHT[PHT_CDB_1]) < 2'b11)
						PHT[PHT_CDB_1]		<= 		`SD PHT[PHT_CDB_1] + 1; // Increment PHT
					else if (!CDB_take_branch_1 && (PHT[PHT_CDB_1]) > 2'b00)
						PHT[PHT_CDB_1]		<= 		`SD PHT[PHT_CDB_1] - 1; // Decrement PHT
				end
			end			
			if(CDB_valid_inst_2) begin
				if(CDB_cond_branch_2 || CDB_uncond_branch_2) begin
					BTB_addr[CDB_set_2]		<=		`SD CDB_tar_addr_2;
					BTB_tags[CDB_set_2]		<=		`SD CDB_tag_2;
					BTB_valid[CDB_set_2]	<=		`SD 1'b1;
				end	
				if(CDB_cond_branch_2 & !same_bht) begin
					BHT[BHT_CDB_2]			<= 		`SD {BHT[BHT_CDB_2] [`PHT_IDX-2:0], CDB_take_branch_2}; // Update BHT
					if(CDB_take_branch_2 && (PHT[PHT_CDB_2]) < 2'b11)
						PHT[PHT_CDB_2]		<= 		`SD PHT[PHT_CDB_2] + 1; // Increment PHT
					else if (!CDB_take_branch_2 && (PHT[PHT_CDB_2]) > 2'b00)
						PHT[PHT_CDB_2]		<= 		`SD PHT[PHT_CDB_2] - 1; // Decrement PHT
				end
				else begin // If same_bht
					BHT[BHT_CDB_2]			<= 		`SD {BHT[BHT_CDB_2] [`PHT_IDX-3:0], CDB_take_branch_1, CDB_take_branch_2}; // Update BHT
					if(CDB_take_branch_1 && CDB_take_branch_2 && (PHT[PHT_CDB_1] == 2'b00))	// This section checks if both branches point to the same PHT index
						PHT[PHT_CDB_1]		<=		`SD 2'b10;								// in this case, either one predicts 1 and the other 0 so they cancel
					else if (CDB_take_branch_1 && CDB_take_branch_2)						// therefore there is no change, otherwise if they both predict 1,
						PHT[PHT_CDB_1]		<=		`SD 2'b11;								// The next prediction is set to either 10 or 11, guaranteed. For 0
					if(!CDB_take_branch_1 && !CDB_take_branch_2 && (PHT[PHT_CDB_1] == 2'b11)) // it gets set to 01 or 00, guaranteed.
						PHT[PHT_CDB_1]		<=		`SD 2'b01;
					else if (!CDB_take_branch_1 && !CDB_take_branch_2)
						PHT[PHT_CDB_1]		<=		`SD 2'b00;						
				end
			end
		end
	end

	assign next = (stack_pointer == 0) 				? `RAS_SIZE-1 :
					stack_pointer-1;

	always_comb begin
		if(if_valid_inst_1 && return_1 && RAS_valid) begin
			ras_tar_addr_1		= 		RAS[next];
			ras_valid_1			=		1'b1;
			ras_tar_addr_2 		= 		64'd0;
			ras_valid_2			=		1'b0;	
		end
		else if(if_valid_inst_2 && return_2 && RAS_valid) begin
			ras_tar_addr_1		= 		64'd0;
			ras_valid_1			= 		1'b0;
			ras_tar_addr_2 		= 		RAS[next];
			ras_valid_2			=		1'b1;
		end
		else begin
			ras_tar_addr_1		= 		64'd0;
			ras_valid_1			= 		1'b0;	
			ras_tar_addr_2 		= 		64'd0;
			ras_valid_2			=		1'b0;		
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @ (posedge clock) begin
		if(reset) begin
			RAS 			<=		`SD {`RAS_SIZE{64'b0}};	
			stack_pointer 	<= 		`SD {`RAS_IDX{1'b0}};
			RAS_valid 		<=		`SD 1'b0;
		end 

		else if (mispredict) begin
			RAS 			<=		`SD {`RAS_SIZE{64'b0}};	
			stack_pointer 	<= 		`SD {`RAS_IDX{1'b0}};
			RAS_valid 		<=		`SD 1'b0;
		end
		else if (stack_pointer == 0) begin		// The next 3 large blocks are essentially copied, it's unfortunate but becasue the RAS is circular
												// I could either have one large block with more if checks or 3 blocks that do slightly different things
												// ie: stack_pointer <= `SD stack_pointer + 1 or - 1.
			if((opc_1 == 6'h34) || (opc_1 == 6'h1a && group_1 == 2'b01)) begin //BSR1 JSR1
				RAS[stack_pointer] 		<=	`SD if_NPC_1;
				stack_pointer			<=	`SD stack_pointer+1;
				RAS_valid 				<= 	`SD 1'b1;
			end
			else if(opc_1 == 6'h1a && group_1 == 2'b10) begin //ret1
				RAS[`RAS_SIZE-1] 			<=	`SD 64'd0;
				stack_pointer			<=	`SD `RAS_SIZE;
			end
			else if(opc_1 == 6'h1a && group_1 == 2'b11) begin //jsrco1
				if(RAS_valid)
					RAS[`RAS_SIZE-1]		<=	`SD if_NPC_1;
				else begin
					RAS[stack_pointer]		<=	`SD if_NPC_1;
					stack_pointer			<=	`SD stack_pointer+1;
					RAS_valid 				<= 	`SD 1'b1;
				end
			end
			else if((opc_2 == 6'h34) || (opc_2 == 6'h1a && group_2 == 2'b01)) begin //BSR2 JSR2
				RAS[stack_pointer] 		<=	`SD if_NPC_2;
				stack_pointer			<=	`SD stack_pointer+1;
				RAS_valid 				<= 	`SD 1'b1;
			end
			else if(opc_2 == 6'h1a && group_2 == 2'b10) begin //ret2
				RAS[`RAS_SIZE-1]			<=	`SD 64'd0;
				stack_pointer				<=	`SD `RAS_SIZE;
			end
			else if(opc_2 == 6'h1a && group_2 == 2'b11) begin //jsrco2
				if(RAS_valid)
					RAS[`RAS_SIZE-1]		<=	`SD if_NPC_2;
				else begin
					RAS[stack_pointer]		<=	`SD if_NPC_2;
					stack_pointer			<=	`SD stack_pointer+1;
					RAS_valid 				<= 	`SD 1'b1;
				end
			end
		end
		else if (stack_pointer == `RAS_SIZE-1) begin
			if((opc_1 == 6'h34) || (opc_1 == 6'h1a && group_1 == 2'b01)) begin //BSR1 JSR1
				RAS[stack_pointer] 		<=	`SD if_NPC_1;
				stack_pointer			<=	`SD 1'b0;
				RAS_valid 				<= 	`SD 1'b1;
			end
			else if(opc_1 == 6'h1a && group_1 == 2'b10) begin //ret1
				RAS[stack_pointer-1] 	<=	`SD 64'd0;
				stack_pointer			<=	`SD stack_pointer-1;
			end
			else if(opc_1 == 6'h1a && group_1 == 2'b11) begin //jsrco1
				if(RAS_valid)
					RAS[stack_pointer-1]	<=	`SD if_NPC_1;
				else begin
					RAS[stack_pointer]		<=	`SD if_NPC_1;
					stack_pointer			<=	`SD 1'b0;
					RAS_valid 				<= 	`SD 1'b1;
				end
			end
			else if((opc_2 == 6'h34) || (opc_2 == 6'h1a && group_2 == 2'b01)) begin //BSR2 JSR2
				RAS[stack_pointer] 		<=	`SD if_NPC_2;
				stack_pointer			<=	`SD 1'b0;
				RAS_valid 				<= 	`SD 1'b1;
			end
			else if(opc_2 == 6'h1a && group_2 == 2'b10) begin //ret2
				RAS[stack_pointer-1]	<=	`SD 64'd0;
				stack_pointer			<=	`SD stack_pointer-1;
			end
			else if(opc_2 == 6'h1a && group_2 == 2'b11) begin //jsrco2
				if(RAS_valid)
					RAS[stack_pointer-1]	<=	`SD if_NPC_2;
				else begin
					RAS[stack_pointer]		<=	`SD if_NPC_2;
					stack_pointer			<=	`SD 1'b0;
					RAS_valid 				<= 	`SD 1'b1;
				end
			end
		end
		else begin
			if((opc_1 == 6'h34) || (opc_1 == 6'h1a && group_1 == 2'b01)) begin //BSR1 JSR1
				RAS[stack_pointer] 		<=	`SD if_NPC_1;
				stack_pointer			<=	`SD stack_pointer+1;
				RAS_valid 				<= 	`SD 1'b1;
			end
			else if(opc_1 == 6'h1a && group_1 == 2'b10) begin //ret1
				RAS[stack_pointer-1] 	<=	`SD 64'd0;
				stack_pointer			<=	`SD stack_pointer-1;
			end
			else if(opc_1 == 6'h1a && group_1 == 2'b11) begin //jsrco1
				if(RAS_valid)
					RAS[stack_pointer-1]	<=	`SD if_NPC_1;
				else begin
					RAS[stack_pointer]		<=	`SD if_NPC_1;
					stack_pointer			<=	`SD stack_pointer+1;
					RAS_valid 				<= 	`SD 1'b1;
				end
			end
			else if((opc_2 == 6'h34) || (opc_2 == 6'h1a && group_2 == 2'b01)) begin //BSR2 JSR2
				RAS[stack_pointer] 		<=	`SD if_NPC_2;
				stack_pointer			<=	`SD stack_pointer+1;
				RAS_valid 				<= 	`SD 1'b1;
			end
			else if(opc_2 == 6'h1a && group_2 == 2'b10) begin //ret2
				RAS[stack_pointer-1]	<=	`SD 64'd0;
				stack_pointer			<=	`SD stack_pointer-1;
			end
			else if(opc_2 == 6'h1a && group_2 == 2'b11) begin //jsrco2
				if(RAS_valid)
					RAS[stack_pointer-1]	<=	`SD if_NPC_2;
				else begin
					RAS[stack_pointer]		<=	`SD if_NPC_2;
					stack_pointer			<=	`SD stack_pointer+1;
					RAS_valid 				<= 	`SD 1'b1;
				end
			end
		end
	end							
endmodule