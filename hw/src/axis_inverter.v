`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.02.2026 18:51:09
// Design Name: 
// Module Name: axis_inverter
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


module axis_inverter#(
    parameter DATA_WIDTH = 32
)(
    input   wire                    clk,
    input   wire                    rst_n,          // Active LOW Reset (AXI Standard)
    
    // Slave Interface (Data Input from DMA MM2S)
    input   wire [DATA_WIDTH-1:0]   s_axis_tdata,
    input   wire                    s_axis_tvalid,
    input   wire                    s_axis_tlast,
    output  wire                    s_axis_tready,
    
    // Master Interface (Data Output to DMA S2MM)
    output  wire [DATA_WIDTH-1:0]   m_axis_tdata,
    output  wire                    m_axis_tvalid,
    output  wire                    m_axis_tlast,
    input   wire                    m_axis_tready
    );
    
    // 1. Handshake "Passthrough"
    assign s_axis_tready = m_axis_tready;   
    assign m_axis_tvalid = s_axis_tvalid;   
    
    // 2. Control Signal (Critical for DMA)
    assign m_axis_tlast  = s_axis_tlast;
    
    // 3. Data processing 
    assign m_axis_tdata  = ~s_axis_tdata;   
    
endmodule
