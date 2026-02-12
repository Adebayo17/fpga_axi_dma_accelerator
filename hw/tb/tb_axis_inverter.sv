`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.02.2026 12:20:58
// Design Name: 
// Module Name: tb_axis_inverter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_axis_inverter;

    // --- 1. CONFIGURATION ---
    localparam DATA_WIDTH = 32;
    localparam CLK_PERIOD = 10; // 100 MHz

    // --- 2. SIGNALS ---
    logic clk = 0;
    logic rst_n;

    // AXIS Master Interface (Stimulus - DMA role played)
    logic [DATA_WIDTH-1:0]  s_axis_tdata;
    logic                   s_axis_tvalid;
    logic                   s_axis_tlast;
    logic                   s_axis_tready;  // DUT output

    // AXIS Slave Interface (Monitor - Next memory/stage played)
    logic [DATA_WIDTH-1:0]  m_axis_tdata;   // DUT output
    logic                   m_axis_tvalid;  // DUT output
    logic                   m_axis_tlast;   // DUT output
    logic                   m_axis_tready;

    // TB variables
    int error_count = 0;
    int transaction_count = 0;

    // --- 3. DUT INSTANTIATION  ---
    axis_inverter #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .* );                               // Implicit named port connection

    // --- 4. CLOCK GENERATION ---
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- 5. STIMULUS TASKS (DRIVER) ---
    
    // Tadk : Send a data and wait for acceptance
    task drive_transaction(input [DATA_WIDTH-1:0] data);
        begin
            // 1. Put the data on the bus
            s_axis_tdata  <= data;
            s_axis_tvalid <= 1;
            
            // 2. Wait for Handshake (VALID=1 && READY=1)
            // We check on RISING_EDGE that the DUT is ready to accpet
            do begin
                @(posedge clk);
            end while (s_axis_tready == 0); // As long as the DUT says "Wait!", we'll keep going.
            
            // 3. The transaction has gone through, we remove the Valid
            s_axis_tvalid <= 0;
        end
    endtask

    // --- 6. PRESSION MANAGEMENT (BACKPRESSURE) ---
    // This process simulates a temperamental slave who isn't always ready.
    // This forces your DUT to manage breaks.
    always @(posedge clk) begin
        if (!rst_n) 
            m_axis_tready <= 0;
        else 
            // Randomly generates 0 or 1 for READY
            m_axis_tready <= $random; 
    end

    // --- 7. MONITORING (CHECKER AUTOMATIQUE) ---
    // Checks data accuracy for each valid transaction
    always @(posedge clk) begin
        // A transaction occurs on the output IF Valid=1 AND Ready=1
        if (m_axis_tvalid && m_axis_tready) begin
            
            // Logical Verification: INVERSION
            if (m_axis_tdata !== ~s_axis_tdata) begin
                $error("[FAIL] Time %0t: Mismatch! Input=%h, Output=%h (Expected %h)", 
                        $time, s_axis_tdata, m_axis_tdata, ~s_axis_tdata);
                error_count++;
            end else begin
                transaction_count++;
            end
        end
    end

    // --- 8. MAIN TEST SCENARIO ---
    initial begin
        // Setup initial
        $display("--- START AXIS INVERTER SIMULATION ---");
        rst_n = 0;
        s_axis_tvalid = 0;
        s_axis_tdata = 0;
        m_axis_tready = 1; // At the beginning, we are ready

        // Reset Pulse
        #100;
        rst_n = 1;
        #20;

        // TEST 1 : Continuous Flow (Burst)
        // We send 10 values in succession
        $display("[TB_AXIS_INVERTER][TEST_1] Sending 10 values ​​in a burst...");
        repeat(10) begin
            automatic logic [31:0] rand_val = $random;
            drive_transaction(rand_val);
        end

        // Petite pause (Idle)
        s_axis_tvalid = 0;
        #100;

        // TEST 2 : Specifics data (Corner Cases)
        $display("[TB_AXIS_INVERTER][TEST_2] Limit value test (0x00, 0xFF...)");
        drive_transaction(32'h00000000); // Should be FFFFFFFF
        drive_transaction(32'hFFFFFFFF); // Should be 00000000
        drive_transaction(32'hAAAAAAAA); // Should be 55555555

        // TEST 3 : Intense Backpressure Simulation
        // The 'always' block above already handles m_axis_tready randomly.
        // We're just sending a lot of data to see if it holds up.
        $display("[TB_AXIS_INVERTER][TEST_3] Stress Test avec Backpressure aleatoire...");
        repeat(50) begin
            drive_transaction($random);
        end

        // End of the simulation
        #100;
        $display("\n========================================");
        $display(" RESULTS");
        $display(" Successful Transactions: %0d", transaction_count);
        $display(" Errors detected     : %0d", error_count);
        $display("========================================");
        
        if (error_count == 0) $display("--- SUCCESS : MODULE VALIDATED ---");
        else $display("--- FAIL ---");
        
        $finish;
    end
endmodule
