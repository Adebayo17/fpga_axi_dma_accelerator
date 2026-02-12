# AXI4-Stream Data Accelerator on Zynq-7000

## 🚀 Project Overview
This project demonstrates a high-performance **Hardware-Software Co-design** architecture on the Digilent Arty Z7-20 (Xilinx Zynq-7000 SoC). 

It implements a custom hardware accelerator (RTL) capable of processing data streams via **AXI DMA** (Direct Memory Access). The system offloads processing tasks from the ARM Cortex-A9 processor to the FPGA fabric, ensuring efficient data movement and cache coherency.

**Key Features:**
* **Custom IP Design:** AXI4-Stream compliant Verilog module.
* **System Integration:** AXI DMA, AXI Interconnect, and Zynq PS via Vivado IP Integrator.
* **Embedded Software:** Bare-metal C driver handling DMA transfers, Cache flushing/invalidation, and verification.
* **Verification:** SystemVerilog testbench for the AXI-Stream interface.

## 🏗️ System Architecture

![Block Design](docs/block_design.png)
*(Note: Place a screenshot of your Vivado Block Design here)*

**Data Flow:**
1.  **CPU (PS):** Generates data in DDR Memory.
2.  **DMA (MM2S):** Reads data from DDR and streams it to the FPGA IP.
3.  **Accelerator (PL):** Processes data (Bitwise Inversion) at wire speed.
4.  **DMA (S2MM):** Writes the processed data back to DDR Memory.
5.  **CPU (PS):** Verifies the results.

## 📂 Repository Structure

```text
.
├── hw/                 # Hardware Design
│   ├── src/            # Verilog/SystemVerilog sources (Accelerator IP)
│   ├── constraints/    # Physical constraints (.xdc)
│   └── scripts/        # Tcl scripts to recreate the Vivado project
├── sw/                 # Embedded Software
│   └── src/            # C source code (DMA driver and Main application)
└── docs/               # Documentation and diagrams
```

## 🛠️ Prerequisites
- **Hardware**: Digilent Arty Z7-20 (or any Zynq-7000 board with adaptation).
- **Software**: Xilinx Vivado & Vitis (2024.1 or newer recommended).
- **Terminal**: Tera Term, PuTTY, or Vitis Serial Terminal.


## ⚙️ How to Build & Run

### 1. Hardware Generation (Vivado)
To generate the block design and bitstream:

1. Open Vivado
2. Run the Tcl script located in `hw/scripts/regenerate_project.tcl` (Tools &rarr; Run Tcl Script...).
3. Click **Generate Bitstream**.
4. Export Hardware: **File &rarr; Export &rarr; Export Hardware** (Select "Include bitstream"). Save the `.xsa` file.

### 2. Software Setup (Vitis)

1. Open Vitis IDE and create a new workspace.
2. **Create Platform Project:**
    * Select the `.xsa` file exported from Vivado.
    * OS: `standalone` (for bare-metal), Processor: `ps7_cortexa9_0`.
    * **IMPORTANT**: Check "Generate Boot Components."
3. **Create Application Project:**
    * Select the platform created above.
    * Template: "Empty Application" or "Hello World".
4. **Import Source:**
    * Copy the content of `sw/src/main.c` into your application's source folder.
5. Build the project (🔨 Hammer icon)

### 3. Execution

1. Connect the Arty Z7 to your PC via USB.
2. In Vitis, roght-click the application **&rarr; Run As &rarr; 1 Launch Hardware (Single Application Debug)**
    * *Note:* Vitis will automatically program the FPGA bitstream and load the C code.

## 🐞 Debugging & Console Output
To see the application output, you must configure a Serial Terminal **before** running the code.

**Using Vitis Serial Terminal:**

1. Open the **Vitis Serial Terminal** tab (Window &rarr; Show View &rarr; Terminal).
2. Click the + icon to connect.
3. **Setting:** 
    * **Port:** COMx (Check Device Manager for "USB Serial Port").
    * **Baud Rate:** 115200
    * **Data/Stop/Parity:** 8 / 1 / None.
4. **Launch the Run**

**Expected Output**
```text
init:done
Arty Z7 -Z20 Rev. B Demo Image

--- START AXI-STREAM ACCELERATOR TEST ---
DMA Initialization...
Filling the TX buffer...
DMA transfer launched...
Transfer complete. Verification...

--- SUCCESS: The accelerator reversed the data correctly! ---
```


## ⚠️ Common Issues
- **Terminal is empty:** The program runs too fast. Connect the terminal before running, or press the **RESET** button on the board (Red button) to restart the execution.

- **"Platform.h not found":** If you chose "Empty Application", remove `#include "platform.h"`, `init_platform()` and `cleanup_platform` calls from the main C file.

- **DMA Transfer Fails:** Ensure `TLAST` signal is correctly propagated in the Verilog IP.