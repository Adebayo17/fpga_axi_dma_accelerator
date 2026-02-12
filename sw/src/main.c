#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xaxidma.h"      // Xilinx DMA Driver
#include "xparameters.h"  // Parameters generated from Vivado (Addresses)

// --- CONFIGURATION ---
// DMA's ID IN xparameters.h
#define DMA_DEV_ID      XPAR_AXI_DMA_0_DEVICE_ID

// Buffers Memory Address (In Zynq's DDR)
// We choose "high" addresses so as not to overwrite the program code
#define TX_BUFFER_BASE  0x00A00000
#define RX_BUFFER_BASE  0x00B00000

// Transfer size (in bytes)
// 32 integers of 32 bits = 128 bytes
#define TEST_LENGTH     128

XAxiDma AxiDma; // DMA driver instance

int main()
{
    init_platform();
    print("\n--- START AXI-STREAM ACCELERATOR TEST ---\n\r");

    int Status;
    XAxiDma_Config *CfgPtr;

    // 1. DMA Initialization
    print("DMA Initialization...\n\r");
    CfgPtr = XAxiDma_LookupConfig(DMA_DEV_ID);
    if (!CfgPtr) {
        print("Error: DMA configuration not found\r\n");
        return XST_FAILURE;
    }

    Status = XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
    if (Status != XST_SUCCESS) {
        print("Error: DMA initialization failed\r\n");
        return XST_FAILURE;
    }

    // Disabling interrupts (Polling mode for simplicity)
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    // 2. Data Preparation in Memory (DDR)
    u32 *TxBufferPtr = (u32 *)TX_BUFFER_BASE;
    u32 *RxBufferPtr = (u32 *)RX_BUFFER_BASE;

    print("Filling the TX buffer...\n\r");
    for(int i = 0; i < TEST_LENGTH/4; i ++) {
        TxBufferPtr[i] = i; // Writing 0, 1, 2, 3...
        RxBufferPtr[i] = 0; // Cleaning RX
    }

    // 3. CACHE FLUSH (CRUCIAL !)
    // The CPU writes to its L1/L2 cache. The DMA reads from the DDR.
    // The CPU must be forced to write its data to DDR before DMA starts.
    Xil_DCacheFlushRange((UINTPTR)TxBufferPtr, TEST_LENGTH);
    Xil_DCacheFlushRange((UINTPTR)RxBufferPtr, TEST_LENGTH); // For Safety

    print("DMA transfer launched...\n\r");

    // 4. Launch of the RX Channel (Device to DMA - S2MM)
    // Always start the RX first! Otherwise, the TX may freeze if the RX is not ready.
    Status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)RxBufferPtr,
                                    TEST_LENGTH, XAXIDMA_DEVICE_TO_DMA);
    if (Status != XST_SUCCESS) {
        print("Error: RX launch failed\r\n");
        return XST_FAILURE;
    }

    // 5. Launch of the TX Channel (DMA to Device - MM2S)
    Status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)TxBufferPtr,
                                    TEST_LENGTH, XAXIDMA_DMA_TO_DEVICE);
    if (Status != XST_SUCCESS) {
        print("Error: TX launch failed\r\n");
        return XST_FAILURE;
    }

    // 6. Active waiting (Polling)
    // We are waiting for both channels to finish
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE) ||
           XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA)) {
           // We could add a timeout here
    }

    print("Transfer complete. Verification...\n\r");

    // 7. CACHE INVALIDATE (CRUCIAL !)
    // DMA wrote to DDR. The CPU needs to invalidate its cache to be forced
    // to read the DDR (and not its old cached data).
    Xil_DCacheInvalidateRange((UINTPTR)RxBufferPtr, TEST_LENGTH);

    // 8. Comparison of results
    int error_count = 0;
    for(int i = 0; i < TEST_LENGTH/4; i ++) {
        u32 sent = TxBufferPtr[i];
        u32 received = RxBufferPtr[i];
        u32 expected = ~sent; // Our hardware performs a bit-by-bit inversion

        if (received != expected) {
            xil_printf("Error at index %d: Sent 0x%08x, Received 0x%08x, Expected 0x%08x\r\n",
                        i, sent, received, expected);
            error_count++;
        }
    }

    if (error_count == 0) {
        print("\n--- SUCCESS: The accelerator reversed the data correctly! ---\n\r");
    } else {
        print("\n--- FAILURE: Errors have been detected ---\n\r");
    }

    cleanup_platform();
    return 0;
}
