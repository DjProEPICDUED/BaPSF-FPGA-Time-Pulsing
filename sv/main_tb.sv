`timescale 1ns/1ps

module main_tb;

    // =========================================================================
    // Signals
    // =========================================================================
    // Inputs to DUT
    logic clk_100mhz;
    logic rst;
    logic ext_btn_signal;
    logic btn_add_time;
    logic btn_sub_time;

    // Outputs from DUT
    logic [9:0] output_pulse;
    logic locked;
    logic triggerOut1;
    logic triggerOut2;
    logic triggerOut3;
    logic triggerOut4;
    logic triggerOut5;
    logic led4_r;
    logic led4_g;
    logic led4_b;

    // =========================================================================
    // Clock Generation (100 MHz)
    // =========================================================================
    initial begin
        clk_100mhz = 1'b0;
        forever #5 clk_100mhz = ~clk_100mhz; // 10 ns period
    end

    // =========================================================================
    // Device Under Test (DUT) Instantiation
    // =========================================================================
    top dut (
        .clk_100mhz     (clk_100mhz),
        .rst            (rst),
        .ext_btn_signal (ext_btn_signal),
        .btn_add_time   (btn_add_time),
        .btn_sub_time   (btn_sub_time),
        .output_pulse   (output_pulse),
        .locked         (locked),
        .triggerOut1    (triggerOut1),
        .triggerOut2    (triggerOut2),
        .triggerOut3    (triggerOut3),
        .triggerOut4    (triggerOut4),
        .triggerOut5    (triggerOut5),
        .led4_r         (led4_r),
        .led4_g         (led4_g),
        .led4_b         (led4_b)
    );

    // =========================================================================
    // Verification Tasks
    // =========================================================================

    // Task: Press the external button for a programmable width (ns)
    task automatic press_ext_button(input int unsigned width_ns);
        begin
            $display("[%0t] Pressing external button for %0d ns...", $time, width_ns);
            ext_btn_signal = 1'b1;
            #(width_ns);
            ext_btn_signal = 1'b0;
            $display("[%0t] External button released.", $time);
        end
    endtask

    // Task: Verify that triggerOut pins and first pulse align on same cycle
    task automatic verify_trigger_alignment(input string testname);
        event trig_event;
        begin
            fork
                begin
                    @(posedge triggerOut1);
                    -> trig_event;
                end
                begin
                    #500000; // timeout 500 us
                    $fatal("Timeout waiting for trigger outputs (%s)", testname);
                end
            join_any
            @(trig_event);
            if (output_pulse[0] !== 1'b1)
                $error("[%0t] %s: First pulse not aligned with trigger outputs", $time, testname);
            if (!(triggerOut1 && triggerOut2 && triggerOut3 && triggerOut4 && triggerOut5))
                $error("[%0t] %s: One or more triggerOutX signals not asserted", $time, testname);
        end
    endtask

    // Task: Press the "Add Time" button with a realistic hold time
    task automatic press_add_button();
        begin
            $display("[%0t] Pressing ADD TIME button...", $time);
            btn_add_time = 1'b1;
            #50; // Hold long enough for the 100MHz synchronizer to catch it cleanly
            btn_add_time = 1'b0;
        end
    endtask

    // Task: Press the "Sub Time" button with a realistic hold time
    task automatic press_sub_button();
        begin
            $display("[%0t] Pressing SUB TIME button...", $time);
            btn_sub_time = 1'b1;
            #50;
            btn_sub_time = 1'b0;
        end
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        // Waveform dump for simulators that support VCD
        $dumpfile("main_tb.vcd");
        $dumpvars(0, main_tb);

        $display("===============================================================");
        $display(" Starting Simulation: Variable Frequency Ring Counter Testbench");
        $display("===============================================================");

        // 1. Initialize all inputs
        rst            = 1'b1; // Assert reset
        ext_btn_signal = 1'b0;
        btn_add_time   = 1'b0;
        btn_sub_time   = 1'b0;

        // 2. Power-on reset sequence
        #100;
        $display("[%0t] Releasing Reset...", $time);
        rst = 1'b0;

        // Give the system a few cycles after reset release
        #100;

        // 3. Wait for the MMCM to achieve initial lock
        $display("[%0t] Waiting for MMCM lock...", $time);
        wait(locked == 1'b1);
        $display("[%0t] MMCM Locked!", $time);

        // 4. Wait for the initial DRP state machine to settle
        // The DRP controller executes ~23 cycles upon startup to load State 10
        #2000; 
        
        if (led4_r && led4_g && led4_b) 
            $display("[%0t] System is stable at BASE state (White LED).", $time);
        else 
            $error("[%0t] LED status incorrect on startup!", $time);

        // 5. Test 1: Fire the base frequency sequence (50.0 ns)
        $display("\n--- TEST 1: Baseline Pulse Sequence (State 10) ---");
        press_ext_button(120); // Hold >1 clk_var period to guarantee capture
        verify_trigger_alignment("TEST 1");
        // Wait enough time for all 10 channels to fire (10 * 50ns = 500ns)
        #1000; 

        // 6. Test 2: Dynamic Reconfiguration (Shift to State 11)
        $display("\n--- TEST 2: Dynamic Reconfiguration (+0.5 ns) ---");
        press_add_button();
        
        // Wait for the DRP to drop the lock, write the new hex values, and re-lock
        // Note: Simulation IP takes time to re-lock.
        wait(locked == 1'b0);
        $display("[%0t] MMCM unlocked, shifting frequency...", $time);
        
        wait(locked == 1'b1);
        $display("[%0t] MMCM Re-locked at new frequency!", $time);
        
        // Give the state machine a moment to assert drp_srdy
        #1000; 

        if (led4_g && !led4_r && !led4_b) 
            $display("[%0t] System is stable at SHIFTED state (Green LED).", $time);

        // 7. Test 3: Fire the new frequency sequence (~50.5 ns)
        $display("\n--- TEST 3: Shifted Pulse Sequence (State 11) ---");
        press_ext_button(120);
        verify_trigger_alignment("TEST 3");
        
        // Wait enough time for all 10 channels to fire
        #1000;

        // 8. Test 4: Shift downwards (Return to State 10, then to State 9)
        $display("\n--- TEST 4: Downward Shift (-1.0 ns total) ---");
        press_sub_button(); // Go down to State 10
        #2000;              // Wait for shift
        press_sub_button(); // Go down to State 9
        
        wait(locked == 1'b0);
        wait(locked == 1'b1);
        #1000;

        if (led4_b && !led4_r && !led4_g) 
            $display("[%0t] System is stable at SUB-BASE state (Blue LED).", $time);

        press_ext_button(120);
        verify_trigger_alignment("TEST 4");
        #1000;

        $display("\n===============================================================");
        $display(" Simulation Complete.");
        $display("===============================================================");
        $finish;
    end

endmodule