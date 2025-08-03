`ifndef TURTLE_CPU_TOP_TB
`define TURTLE_CPU_TOP_TB

// turtle_cpu_top_tb.sv
// author: Tom Riley
// date: 2025-07-10

// Testbench for the turtle_cpu_top module
module turtle_cpu_top_tb;
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, turtle_cpu_top_tb);
    end

    // Signals
    logic reset_btn;
    logic manual_clk_sw;
    logic pulse_clk_btn;

    int cycle_count = 0;

    // Instantiate the turtle CPU top module
    turtle_cpu_top uut (
        .reset_btn(reset_btn),
        .manual_clk_sw(manual_clk_sw),
        .pulse_clk_btn(pulse_clk_btn)
    );

    // Test sequence
    initial begin
        string initial_instruction_memory_file = "initial_instruction_memory.txt";
        string final_data_memory_file = "final_data_memory.txt";
        string final_register_file = "final_register_file.txt";

        reset_btn = 1;
        manual_clk_sw = 0;
        pulse_clk_btn = 0;

        #2us;

        reset_btn = 0;

        if (!$value$plusargs("initial_instruction_memory_file=%s", initial_instruction_memory_file)) begin
            $display("No initial instruction memory file provided, using default.");
        end
        $display("Loading initial instruction memory from %s", initial_instruction_memory_file);
        $readmemb(initial_instruction_memory_file, uut.instruction_memory_inst.mem);

        #20ms;

        $display("Turtle CPU Top-level testbench completed successfully!");

        if (!$value$plusargs("final_data_memory_file=%s", final_data_memory_file)) begin
            $display("No final data memory file provided, using default.");
        end
        $display("Saving final data memory to %s", final_data_memory_file);
        $writememb(final_data_memory_file, uut.data_memory_inst.mem);
        
        if (!$value$plusargs("final_register_file=%s", final_register_file)) begin
            $display("No final register file provided, using default.");
        end
        $display("Saving final register file to %s", final_register_file);
        $writememb(final_register_file, uut.register_file_inst.mem);

        $finish;
    end

    always @(edge uut.reset_n) begin
        if (uut.reset_n) begin
            $display("Reset deasserted!");
        end
        else begin
            $display("Reset asserted!");
        end
    end

    always @(posedge uut.clk or edge uut.reset_n) begin
        if (uut.reset_n) begin
            // First, let's add detailed decoder signal monitoring
            $display("cycle=%4d pc=%4d, instruction=0x%4h", cycle_count, uut.pc, uut.instruction);
            $display("  DECODER_SIGNALS: branch_inst=%b, jump_branch_sel=%b, uncond_branch=%b, op=%s", 
                uut.decoder_inst.branch_instruction,
                uut.jump_branch_select,
                uut.unconditional_branch,
                uut.decoder_inst.op.name
            );
            
            // Show the actual instruction classification
            if (uut.decoder_inst.branch_instruction) begin
                $display("  BRANCH_INSTRUCTION: cond=%s, addr_imm=0x%03h", 
                    uut.branch_condition.name(), uut.address_immediate);
            end else begin
                $display("  NON_BRANCH: op=%s, func=%s", 
                    uut.decoder_inst.op.name,
                    uut.decoder_inst.op == OPCODE_REG_MEMORY ? uut.decoder_inst.reg_mem_func.name : 
                    uut.decoder_inst.alu_output_enable ? uut.decoder_inst.alu_function.name : "N/A"
                );
            end
            
            $display("  STATE: acc=0x%02h, gpr=%p", uut.acc_out, uut.register_file_inst.gpr);
            
            // Monitor ALU flags and status register updates
            if (uut.decoder_inst.status_write_enable) begin
                $display("  STATUS_UPDATE: alu_zero=%b, alu_positive=%b, alu_carry=%b, alu_overflow=%b, status_we=%b",
                    uut.alu_inst.zero_flag,
                    uut.alu_inst.positive_flag,
                    uut.alu_inst.carry_flag,
                    uut.alu_inst.signed_overflow,
                    uut.decoder_inst.status_write_enable
                );
                $display("  STATUS_DETAIL: old_status=0x%02h, new_status=0x%02h, reg_data_bus=0x%02h",
                    uut.register_file_inst.mem[15], // Previous STATUS value
                    {4'b0, uut.alu_inst.signed_overflow, uut.alu_inst.carry_flag, uut.alu_inst.positive_flag, uut.alu_inst.zero_flag},
                    uut.register_data_bus
                );
            end
            
            // Enhanced monitoring for branch instructions - use the correct branch detection
            if (uut.decoder_inst.branch_instruction) begin
                $display("  BRANCH_DEBUG: cond=%s, status=0x%02h, addr_imm=0x%03h, pc_rel=%b",
                    uut.branch_condition.name(),
                    uut.register_data_bus,
                    uut.address_immediate,
                    uut.pc_relative
                );
                $display("  BRANCH_CALC: target_offset=0x%03h, branch_addr=0x%03h, branch_taken=%b",
                    uut.program_counter_inst.target_offset,
                    uut.program_counter_inst.branch_addr,
                    uut.program_counter_inst.branch_taken
                );
                $display("  PC_LOGIC: next_pc=0x%03h, current_pc=0x%03h",
                    uut.program_counter_inst.next_pc,
                    uut.pc
                );
                
                // Detailed branch condition evaluation
                $display("  BRANCH_EVAL: zero_flag=%b, pos_flag=%b, carry_flag=%b, overflow_flag=%b",
                    uut.register_data_bus[0], // ZERO_FLAG 
                    uut.register_data_bus[1], // POSITIVE_FLAG
                    uut.register_data_bus[2], // CARRY_FLAG
                    uut.register_data_bus[3]  // SIGNED_OVERFLOW_FLAG
                );
                
                // Show how branch condition is being evaluated
                case (uut.branch_condition)
                    COND_ZERO: $display("  BZ_EVAL: zero_flag=%b, should_branch=%b", 
                        uut.register_data_bus[0], uut.register_data_bus[0] == 1'b1);
                    COND_NOT_ZERO: $display("  BNZ_EVAL: zero_flag=%b, should_branch=%b", 
                        uut.register_data_bus[0], uut.register_data_bus[0] == 1'b0);
                    COND_POSITIVE: $display("  BP_EVAL: pos_flag=%b, should_branch=%b", 
                        uut.register_data_bus[1], uut.register_data_bus[1] == 1'b1);
                    COND_NEGATIVE: $display("  BN_EVAL: pos_flag=%b, should_branch=%b", 
                        uut.register_data_bus[1], uut.register_data_bus[1] == 1'b0);
                    COND_CARRY_SET: $display("  BCS_EVAL: carry_flag=%b, should_branch=%b", 
                        uut.register_data_bus[2], uut.register_data_bus[2] == 1'b1);
                    COND_CARRY_CLEARED: $display("  BCC_EVAL: carry_flag=%b, should_branch=%b", 
                        uut.register_data_bus[2], uut.register_data_bus[2] == 1'b0);
                    default: $display("  UNKNOWN_BRANCH_CONDITION: %s", uut.branch_condition.name());
                endcase
            end
            
            cycle_count <= cycle_count + 1;
        end
    end

endmodule

`endif // TURTLE_CPU_TOP_TB
