parameter CLOCK_PERIOD = 10;

module rename_tb;

	//
	// Inputs from Elsewhere (ID, RS, RoB, CDB) -----------------------------------------------------------------
	//

	logic 										clock, reset;

	// Inputs to RAT from ID stage
	logic [`ARF_IDX-1:0]	id_rega_1, id_regb_1, id_rega_2, id_regb_2;
	logic [`ARF_IDX-1:0]	id_dest_reg_1, id_dest_reg_2;
	logic					id_valid_inst_1, id_valid_inst_2;

	// Inputs from RoB to RRAT
	logic [`ARF_IDX-1:0]	ROB_dest_reg_1;			// Arch reg at head of the rob
	logic [`PRF_IDX-1:0]	ROB_PRF_reg_1;			// PRF reg at head of the rob
	logic 					commit_en_1;			// Head of the rob is committing

	logic [`ARF_IDX-1:0]	ROB_dest_reg_2;
	logic [`PRF_IDX-1:0]	ROB_PRF_reg_2;
	logic 					commit_en_2;

	// INPUTS FROM ROB TO PRF
	logic [`PRF_IDX-1:0]						PRF_old_1; 			// PRF to be freed
	logic 										PRF_old_valid_1; 

	logic [`PRF_IDX-1:0]						PRF_old_2; 	
	logic 										PRF_old_valid_2; 
	logic 										flush;

	// Inputs from CDB to PRF
	logic [63:0]								CDB_value_1;
	logic [`PRF_IDX-1:0]						CDB_tag_1;
	logic 									 	CDB_en_1;

	logic [63:0]								CDB_value_2;
	logic [`PRF_IDX-1:0]						CDB_tag_2;
	logic 									 	CDB_en_2;

	// OUTPUT TO ROB FROM RAT
	logic [`PRF_IDX-1:0]						PRF_dest_reg_1;		// PRF destination register
	logic [`PRF_IDX-1:0]						PRF_dest_reg_2;
	logic [`PRF_IDX-1:0]						PRF_dest_old_1;		// old PRF destination register associated with ARF
	logic [`PRF_IDX-1:0]						PRF_dest_old_2;	

	// OUTPUTS TO RS FROM RAT
	logic [`PRF_SIZE-1:0]	RS_rega_1, RS_regb_1, RS_rega_2, RS_regb_2;

	// OUTPUTS TO RS FROM PRF
	logic [`PRF_SIZE-1:0][63:0]					PRF_values_out;
	logic [`PRF_SIZE-1:0]						PRF_valid_out;

	//
	// Internal Inputs/Outputs -----------------------------------------------------------------------------
	//

	// FROM RAT TO PRF								
	logic										used_1;
	logic 										used_2;
				
	// FROM RRAT TO (PRF and RAT)
	logic [`ARF_SIZE-1:0][`PRF_IDX-1:0]			rrat_prf_out;	// Mapping of ARCH to PR's (for flushes	
	
	// OUTPUTS TO RAT FROM PRF
	logic [`PRF_IDX-1:0]						free_reg_1;	
	logic [`PRF_IDX-1:0]						free_reg_2;

	// Debugging output to RAT from PRF
	logic [`PRF_SIZE-1:0]						PRF_free; 

	// Debugging output from RAT
	logic [`ARF_SIZE-1:0][`PRF_IDX-1:0]			PRF_idx;		// Mapping of ARF to PRF










	// Expected outputs
	logic [`PRF_SIZE-1:0][63:0]					PRF_values_out_ex;
	logic [`PRF_SIZE-1:0]						PRF_valid_out_ex;
	logic [63:0]								value_1, value_2;
	
	logic [`PRF_IDX-1:0]						free_reg_1_ex;
	
	logic [`PRF_IDX-1:0]						free_reg_2_ex;

	// Output check logic *** DO WE WANT TO CHECK THE OUTPUT OR THE FULL RAT***
	logic [`ARF_SIZE-1:0][`PRF_IDX-1:0]	lookup_table_predicted;
	logic [`PRF_SIZE-1:0]	RS_rega_1_predicted, RS_regb_1_predicted, 
								RS_rega_2_predicted, RS_regb_2_predicted;
	logic						used_1_predicted,	used_2_predicted;

	logic [`PRF_SIZE-1:0]						PRF_free_ex; 
	logic						correct;
	string 						task_name;

	//----------------------CLOCK----------------------
	always begin 
		#(CLOCK_PERIOD/2); //clock "interval" ... AKA 1/2 the period
		clock=~clock; 
	end 

	//--------------Test bench functions---------------
	task check_result;
		begin
			$display("checking results");		
			correct = (PRF_values_out === PRF_values_out_ex) && 
						(PRF_valid_out === PRF_valid_out_ex) &&
						(free_reg_1 === free_reg_1_ex) &&
						(free_reg_2 === free_reg_2_ex);
			if( !correct ) begin //CORRECT CASE
				$display("@@@ Incorrect at time %4.0f", $time);
				$display("ENDING TESTBENCH : %s failed!", task_name);
				$display("Expected = free 1 = %d, free 2 = %d", free_reg_1_ex, free_reg_2_ex);
				$display("Actual = free 1 = %d, free 2 = %d", free_reg_1, free_reg_2);
				$finish;
			end  
		end
	endtask


		
	task set_prf_inputs;
		input [63:0]								CDB_value_1_in;
		input [`PRF_IDX-1:0]						CDB_tag_1_in;
		input 									 	CDB_en_1_in;

		input [63:0]								CDB_value_2_in;
		input [`PRF_IDX-1:0]						CDB_tag_2_in;
		input 									 	CDB_en_2_in;

		input [`PRF_IDX-1:0]						PRF_old_1_in; 			// PRF to be freed
		input 										PRF_old_valid_1_in; 

		input [`PRF_IDX-1:0]						PRF_old_2_in; 	
		input 										PRF_old_valid_2_in; 

		input 										flush_in;
		begin
			CDB_value_1 = CDB_value_1_in;
			CDB_tag_1 = CDB_tag_1_in;
			CDB_en_1 = CDB_en_1_in;
			CDB_value_2 = CDB_value_2_in;
			CDB_tag_2 = CDB_tag_2_in;
			CDB_en_2 = CDB_en_2_in;
			PRF_old_1 = PRF_old_1_in;
			PRF_old_valid_1 = PRF_old_valid_1_in;
			PRF_old_2 = PRF_old_2_in;
			PRF_old_valid_2 = PRF_old_valid_2_in;
			flush = flush_in;
		end
	endtask

	task set_rat_inputs;
		input [`ARF_IDX-1:0] 				id_rega_1_in;
		input [`ARF_IDX-1:0] 				id_regb_1_in;
		input [`ARF_IDX-1:0]				id_dest_reg_1_in;
		input        						id_valid_inst_1_in;

		input [`ARF_IDX-1:0] 				id_rega_2_in;
		input [`ARF_IDX-1:0] 				id_regb_2_in;
		input [`ARF_IDX-1:0]				id_dest_reg_2_in;
		input        						id_valid_inst_2_in;

		input 								flush_in;
		begin
			id_rega_1 = id_rega_1_in;
			id_regb_1 = id_regb_1_in;
			id_dest_reg_1 = id_dest_reg_1_in;
			id_valid_inst_1 = id_valid_inst_1_in;
			id_rega_2 = id_rega_2_in;
			id_regb_2 = id_regb_2_in;
			id_dest_reg_2 = id_dest_reg_2_in;
			id_valid_inst_2 = id_valid_inst_2_in;
			flush = flush_in;
		end
	endtask

	task set_rrat_inputs;
		input [`ARF_IDX-1:0]						ROB_dest_reg_1_in;			// Arch reg at head of the rob
		input [`PRF_IDX-1:0]						ROB_PRF_reg_1_in;			// PRF reg at head of the rob
		input 										commit_en_1_in;				// Head of the rob is committing

		input [`ARF_IDX-1:0]						ROB_dest_reg_2_in;
		input [`PRF_IDX-1:0]						ROB_PRF_reg_2_in;
		input 										commit_en_2_in;
		begin
			ROB_dest_reg_1 = ROB_dest_reg_1_in;
			ROB_PRF_reg_1 = ROB_PRF_reg_1_in;
			commit_en_1 = commit_en_1_in;
			ROB_dest_reg_2 = ROB_dest_reg_2_in;
			ROB_PRF_reg_2 = ROB_PRF_reg_2_in;
			commit_en_2 = commit_en_2_in;
		end
	endtask
	task dispatch;  //set used 1 and used 2 high, make sure that we set those to no longer free.
		int i;
		input [`ARF_IDX-1:0] 		A1; 
		input [`ARF_IDX-1:0] 		B1;
		input [`ARF_IDX-1:0] 		D1; // Dest 1
		input 				  		valid_1;

		input [`ARF_IDX-1:0] 		A2;
		input [`ARF_IDX-1:0] 		B2;
		input [`ARF_IDX-1:0] 		D2; // Dest 2
		input 				  		valid_2;

		begin
			task_name = "dispatch";
			$display("STARTING TASK : %s %d", task_name, i);
			set_prf_inputs(64'd0, 6'd0, 1'b0, 			// CDB value, PRF, valid (1)
							64'd0, 6'd0, 1'b0,			// CDB value, PRF, valid (2)
							6'd0, 1'b0, 				// Old 1, old valid 1
							6'd0, 1'b0, 				// Old 2, old valid 2
							1'b0); 						// flush

			set_rat_inputs(A1, B1, D1, valid_1,			// A, B, Dest, Valid (1)
							A2, B2, D2, valid_2,		// A, B, Dest, Valid (2)
							1'b0);						// flush

			set_rrat_inputs(32'd0, 64'd0, 1'b0,			// Arch, PRF, valid (1)
							32'd0, 64'd0, 1'b0);		// Arch, PRF, valid (2)
			i = i + 1;
		end
	endtask
	
	task execute;  //set valid bits of CDB tag to 1
		int j;
		input [63:0]				value_1;
		input [`PRF_IDX-1:0]		P1;
		input 						valid_1;

		input [63:0]				value_2;
		input [`PRF_IDX-1:0]		P2;
		input 						valid_2;

		begin
			task_name = "execute";
			$display("STARTING TASK : %s %d", task_name, j);
			set_prf_inputs(value_1, P1, valid_1, 		// CDB value, PRF, valid (1)
							value_2, P2, valid_2, 		// CDB value, PRF, valid (2)
							6'd0, 1'b0, 				// Old 1, old valid 1
							6'd0, 1'b0, 				// Old 2, old valid 2
							1'b0); 						// flush

			set_rat_inputs(32'd0, 32'd0, 32'd0, 1'b0,	// A, B, Dest, Valid (1)
							32'd0, 32'd0, 32'd0, 1'b0,	// A, B, Dest, Valid (2)
							1'b0);						// flush

			set_rrat_inputs(32'd0, 64'd0, 1'b0,			// Arch, PRF, valid (1)
							32'd0, 64'd0, 1'b0);		// Arch, PRF, valid (2)	
			j = j + 1;
		end
	endtask

	task commit;  //free two old PRF's
		int k;
		input [`ARF_IDX-1:0] ARF1;	
		input [`PRF_IDX-1:0] PRF1;
		input [`PRF_IDX-1:0] old_1;
		input 				 valid_1;

		input [`ARF_IDX-1:0] ARF2;	
		input [`PRF_IDX-1:0] PRF2;
		input [`PRF_IDX-1:0] old_2;
		input 				 valid_2;

		begin
			task_name = "commit";
			$display("STARTING TASK : %s %d", task_name, k);
			set_prf_inputs(64'd0, 6'd0, 1'b0, 			// CDB value, PRF, valid (1)
							64'd0, 6'd0, 1'b0,			// CDB value, PRF, valid (2)
							old_1, valid_1, 			// Old 1, old valid 1
							old_2, valid_2, 			// Old 2, old valid 2
							1'b0); 						// flush

			set_rat_inputs(32'd0, 32'd0, 32'd0, 1'b0,	// A, B, Dest, Valid (1)
							32'd0, 32'd0, 32'd0, 1'b0,	// A, B, Dest, Valid (2)
							1'b0);						// flush

			set_rrat_inputs(ARF1, PRF1, valid_1,		// Arch, PRF, valid (1)
							ARF2, PRF2, valid_2);		// Arch, PRF, valid (2)	
			k = k + 1;
		end
	endtask

	task unison;  // dispatch, commit and execute all in the same cycle.
		int k;
		input [`PRF_IDX-1:0] PRF_execute_1;
		input 				 execute_en_1;

		input [`PRF_IDX-1:0] PRF_execute_2;
		input 				 execute_en_2;


		input [`PRF_IDX-1:0] old_1;
		input 				 commit_en_1;

		input [`PRF_IDX-1:0] old_2;
		input 				 commit_en_2;

		input 				 dispatch_en_1;
		input 				 dispatch_en_2;

		input [`ARF_IDX-1:0] ARF_commit_1;
		input [`PRF_IDX-1:0] PRF_commit_1;

		input [`ARF_IDX-1:0] ARF_commit_2;
		input [`PRF_IDX-1:0] PRF_commit_2;

		begin
			task_name = "unison";
			$display("STARTING TASK : %s %d", task_name, k);
			set_prf_inputs(64'd999, PRF_execute_1, execute_en_1, 		// CDB value, PRF, valid (1)
							64'd999, PRF_execute_2, execute_en_2,		// CDB value, PRF, valid (2)
							old_1, commit_en_1, 						// Old 1, old valid 1
							old_2, commit_en_2, 						// Old 2, old valid 2
							1'b0); 										// flush

			set_rat_inputs(32'd0, 32'd1, 32'd2, dispatch_en_1,			// A, B, Dest, Valid (1)
							32'd3, 32'd4, 32'd5, dispatch_en_2,			// A, B, Dest, Valid (2)
							1'b0);										// flush

			set_rrat_inputs(ARF_commit_1, PRF_commit_1, commit_en_1,	// Arch, PRF, valid (1)
							ARF_commit_2, PRF_commit_2, commit_en_2);	// Arch, PRF, valid (2)	
			k = k + 1;
			@(negedge clock);
		end
	endtask

	task dispatch_N; // Dispatch N instructions.
	input int N;
		begin
			for(int i = 0; i<(N/2); i++) begin
				dispatch(32'd0, 32'd1, 32'd2, 1'b1,				// R2 = R0 + R1
						32'd3, 32'd4, 32'd5, 1'b1);				// R5 = R3 + R4
				@(negedge clock);
			end						
		end
	endtask

	task execute_N;  // Execute the instructions in PRF locations (start) to (start + N)
	input int N;
	input int start;
		begin
			for (int i=start; i<N; i=i+2) begin
				execute(64'd999, i, 1'b1,
						64'd999, i+1, 1'b1);
				@(negedge clock);
			end						
		end
	endtask

	task commit_N;  // Commit the instructions in PRF locations (start) to (start + N)
	input int N;
	input int start;
		begin
			for(int i=0, int j=start, int k=start; i<N && j<64 && k<64; i=i+2, j=j+2, k=k+2) begin
				commit(i, j, k, 1'b1,
						i+1, j+1, k+1, 1'b1);
				@(negedge clock);
			end		
		end
	endtask

/*	task commit_N_upper; 
	input int N; 
	input int start;
		begin
			for(int i=0, int j=32, int k=32; i<N; i=i+2, j=j+2, k=k+2) begin
				commit(i, j, k, 1'b1,
						i+1, j+1, k+1, 1'b1);
				@(negedge clock);
			end				
		end
	endtask */

	task print_rat; 
		begin
			int i;
			for(i=0;i<32;i++) begin
				$display("rat @ %d = %d", i, PRF_idx[i]);
			end
		end
	endtask

	task print_rrat; 
		begin
			int i;
			for(i=0;i<32;i++) begin
				$display("rrat @ %d = %d", i, rrat_prf_out[i]);
			end
		end
	endtask

	task print_prf_values; 
		begin
			int i;
			for(i=0;i<64;i++) begin
				$display("prf @ %d = %d", i, PRF_values_out[i]);
			end
		end
	endtask

	task unison_test; 
		begin
			int i,j,k;
			for(i=0; i<5;i++) begin // Dispatch 10 instructions total, 2 at a time
				unison(
					6'd0, 1'b0,		// PRF_execute_1, execute_enable
					6'd1, 1'b0,		
					6'd0, 1'b0,		// PRF_old_1, commit_enable
					6'd1, 1'b0,	
					1'b1,			// dispatch_enable
					1'b1,
					5'd0, 6'd1,		// ARF commit, PRF commit
					5'd1, 6'd2);
			end	
			for(i=0; i<5;i++) begin // Dispatch 5 instructions total, 1 at a time
				unison(
					6'd0, 1'b0,		// PRF_execute_1, execute_enable
					6'd1, 1'b0,		
					6'd0, 1'b0,		// PRF_old_1, commit_enable
					6'd1, 1'b0,	
					1'b1,			// dispatch_enable
					1'b0,
					5'd0, 6'd1,		// ARF commit, PRF commit
					5'd1, 6'd2);
			end	
			for(i=0; i<5;i++) begin // Dispatch 5 instructions total, 1 at a time
				unison(
					6'd0, 1'b0,		// PRF_execute_1, execute_enable
					6'd1, 1'b0,		
					6'd0, 1'b0,		// PRF_old_1, commit_enable
					6'd1, 1'b0,	
					1'b0,			// dispatch_enable
					1'b1,
					5'd0, 6'd1,		// ARF commit, PRF commit
					5'd1, 6'd2);
			end	
			for(i=0, j = 0; i<5;i++, j=j+2) begin // Dispatch 5 instructions, 1 at a time, execute 10 instructions, 2 at a time
				unison(
					j, 1'b1,		// PRF_execute_1, execute_enable
					j+1, 1'b1,		
					6'd0, 1'b0,		// PRF_old_1, commit_enable
					6'd1, 1'b0,	
					1'b0,			// dispatch_enable
					1'b1,
					5'd0, 6'd1,		// ARF commit, PRF commit
					5'd1, 6'd2);
			end	
			for(i=0, j = 10, k = 0; i<5;i++, j=j+2, k = k+2) begin 	// Dispatch 10 instructions, 2 at a time, execute 10 instructions, 2 at a time, 
														// Commit 10 instructions, 2 at a time
				unison(
					j, 1'b1,		// PRF_execute_1, execute_enable
					j+1, 1'b1,		
					k, 1'b1,		// PRF_old_1, commit_enable
					k+1, 1'b1,	
					1'b1,			// dispatch_enable
					1'b1,
					j, 6'd1,		// ARF commit, PRF commit
					j+1, 6'd2);
			end	
		end
	endtask


	task flush_test; 
		begin
			task_name = "flush";
			$display("STARTING TASK : %s", task_name);

			set_prf_inputs(64'd0, 6'd0, 1'b0, 			// CDB value, PRF, valid (1)
							64'd0, 6'd0, 1'b0,			// CDB value, PRF, valid (2)
							6'd0, 1'b0, 				// Old 1, old valid 1
							6'd0, 1'b0, 				// Old 2, old valid 2
							1'b0); 						// flush

			set_rat_inputs(32'd0, 32'd0, 32'd0, 1'b0,	// A, B, Dest, Valid (1)
							32'd0, 32'd0, 32'd0, 1'b0,	// A, B, Dest, Valid (2)
							1'b1);						// flush

			set_rrat_inputs(32'd0, 64'd0, 1'b0,			// Arch, PRF, valid (1)
							32'd0, 64'd0, 1'b0);		// Arch, PRF, valid (2)
		end
	endtask


	task reset_tb; 
		begin
			clock = 0;
			reset = 1;

			set_prf_inputs(64'd0, 6'd0, 1'b0, 			// CDB value, PRF, valid (1)
							64'd0, 6'd0, 1'b0,			// CDB value, PRF, valid (2)
							6'd0, 1'b0, 				// Old 1, old valid 1
							6'd0, 1'b0, 				// Old 2, old valid 2
							1'b0); 						// flush

			set_rat_inputs(32'd0, 32'd0, 32'd0, 1'b0,	// A, B, Dest, Valid (1)
							32'd0, 32'd0, 32'd0, 1'b0,	// A, B, Dest, Valid (2)
							1'b0);						// flush

			set_rrat_inputs(32'd0, 64'd0, 1'b0,			// Arch, PRF, valid (1)
							32'd0, 64'd0, 1'b0);		// Arch, PRF, valid (2)	
			@(negedge clock);
			reset = 0;
		end
	endtask
	//---------------module instatiation---------------
	prf PRF(
		.clock(clock),
		.reset(reset),
		.CDB_value_1(CDB_value_1),
		.CDB_tag_1(CDB_tag_1),
		.CDB_en_1(CDB_en_1),
		.CDB_value_2(CDB_value_2),
		.CDB_tag_2(CDB_tag_2),
		.CDB_en_2(CDB_en_2),
		.used_1(used_1), 						// Internal (From RAT)
		.used_2(used_2),						// Internal
		.PRF_old_1(PRF_old_1),
		.PRF_old_valid_1(PRF_old_valid_1),
		.PRF_old_2(PRF_old_2),
		.PRF_old_valid_2(PRF_old_valid_2),
		.flush(flush),
		.rrat_prf_out(rrat_prf_out),

		.PRF_values_out(PRF_values_out),
		.PRF_valid_out(PRF_valid_out),
		.free_reg_1(free_reg_1),				// Internal (to RAT)
		.free_reg_2(free_reg_2),				// Internal 
		.PRF_free(PRF_free)
		);

	rrat RRAT(
		.clock(clock),
		.reset(reset),
		.ROB_dest_reg_1(ROB_dest_reg_1),
		.ROB_PRF_reg_1(ROB_PRF_reg_1),
		.commit_en_1(commit_en_1),
		.ROB_dest_reg_2(ROB_dest_reg_2),
		.ROB_PRF_reg_2(ROB_PRF_reg_2),
		.commit_en_2(commit_en_2),

		.rrat_prf_out(rrat_prf_out)				// Internal (to PRF and RAT)
		);

	rat RAT(
		.clock(clock),
		.reset(reset),
		.id_rega_1(id_rega_1),
		.id_regb_1(id_regb_1),
		.id_rega_2(id_rega_2),
		.id_regb_2(id_regb_2),
		.id_dest_reg_1(id_dest_reg_1),
		.id_dest_reg_2(id_dest_reg_2),
		.id_valid_inst_1(id_valid_inst_1),
		.id_valid_inst_2(id_valid_inst_2),
		.rrat_prf_out(rrat_prf_out),
		.flush(flush),

		.free_reg_1(free_reg_1),				// Internal (From PRF)
		.free_reg_2(free_reg_2),				// Internal
		.RS_rega_1(RS_rega_1),
		.RS_regb_1(RS_regb_1),
		.RS_rega_2(RS_rega_2),
		.RS_regb_2(RS_regb_2),
		.used_2(used_2),						// Internal (to PRF)
		.used_1(used_1),						// Internal
		.PRF_dest_reg_1(PRF_dest_reg_1),
		.PRF_dest_reg_2(PRF_dest_reg_2),
		.PRF_dest_old_1(PRF_dest_old_1),
		.PRF_dest_old_2(PRF_dest_old_2),
		.PRF_idx(PRF_idx)
		);

	//---------------------RUN TB---------------------

	initial begin 
		$display("STARTING TESTBENCH!\n");
		$monitor(" PRF_free = %b\n PRF_vali = %b\n dest 1 = %d\n dest 2 = %d", PRF_free, PRF_valid_out, PRF_dest_reg_1, PRF_dest_reg_2);
	//	$monitor("%h", rrat_prf_out);
		reset_tb();

/*
		dispatch_N(32);
		// All PRFs now in use.
		execute_N(64, 0);
		// All PRF's are now valid.
		commit_N(32, 0);
		dispatch_N(32);
		execute_N(16, 0);
		commit_N(8, 0);
		dispatch_N(4);
		print_rrat();



		unison(
				6'd0, 1'b1,		// PRF_execute_1, execute_enable
				6'd1, 1'b1,		
				6'd14, 1'b1,	// PRF_old_1, commit_enable
				6'd15, 1'b1,	
				1'b1,			// dispatch_enable
				1'b1,
				5'd0, 6'd1,		// ARF commit, PRF commit
				5'd1, 6'd2);
*/
		print_rrat();
		unison_test();
		print_rrat();
		flush_test();
		@(negedge clock);
		print_rat();
		print_rrat();

		//SUCCESSFULLY END TESTBENCH
		$display("ENDING TESTBENCH : SUCCESS !\n");
		$finish;
		
	end
endmodule
