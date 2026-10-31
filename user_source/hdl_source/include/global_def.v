


`define   DATA_WIDTH                        32
`define   ADDR_WIDTH                        21
`define   DM_WIDTH                          4

`define   ROW_WIDTH                        11
`define   BA_WIDTH                        2

`define	  SDR_CLK_PERIOD				(12) // SDRAM PLL: 1000 MHz / 12 = 83.333333 MHz
// The refresh counter includes zero, so its period is threshold + 1 clocks.
`define   SELF_REFRESH_INTERVAL			(64000000/`SDR_CLK_PERIOD/(2**(`ROW_WIDTH))-1)

