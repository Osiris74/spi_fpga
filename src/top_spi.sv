module top_spi
(
	input               clk     , // Top level system clock input.
	input               sw_0    , // Slide switches.
	input               sw_1    , // Slide switches.
	input   wire        MISO    , // Master input wire
	
	output  wire        spi_clk ,
	output  wire        spi_cs  , 
	output  wire        MOSI    , // Master output wire
	output  wire [3:0]  led		 
);


    localparam CLK_HZ 	  = 50_000_000;  // 50 MHz clock (20 ns period)
    localparam FREQUENCY  = 1_000_000; // 1 MHz SPI clock (1000 ns period)
	 
	 localparam spi_mosi_data = 'hAB;

	 logic [7:0] master_rx_data;
	 logic payload_done;
	 
    // Instantiate DUT
    spi_module_master #(
        .FREQUENCY  ( FREQUENCY ),
        .CLK_HZ     ( CLK_HZ    ),
        .CPOL       (   0       ),
        .CPHA       (   0       )
    )
    i_spi_module_master
    (
        .clk            ( clk           ),
        .rst            ( sw_0          ),
        .spi_en         ( sw_1          ),
        .spi_miso       ( MISO	       ),
        .spi_mosi_data  ( spi_mosi_data ),
        .spi_clk        ( spi_clk       ),
        .spi_mosi       ( MOSI          ),
        .spi_cs         ( spi_cs        ),
        .spi_miso_data  ( master_rx_data),
        .payload_done   ( payload_done  )
    );


endmodule