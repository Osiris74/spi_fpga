module spi_module_slave # 
(
    parameter FREQUENCY     = 1_000_000,
    parameter CLK_HZ        = 50_000_000,

    parameter CPOL          = 0,
    parameter CPHA          = 0,
    parameter PAYLOAD_BITS  = 8
)
(
    input  wire                       clk             , // Top level system clock input.
    input  wire                       rst             , // Asynchronous active low reset.
    input  wire                       spi_en          , // Start/stop signal for SPI
    input  wire                       spi_clk         ,
    input  wire                       spi_mosi        ,
    input  wire                       spi_cs          ,
    input  wire                       receive_en      ,
    input  reg  [PAYLOAD_BITS - 1:0]  spi_miso_data   ,

    output  wire                      spi_miso        ,
    output  reg [PAYLOAD_BITS - 1:0]  spi_mosi_data   ,
    output  reg                       rx_complete
);

// -------------------------------------------------------------------------- 
// Internal parameters.
// 
//------------------------------------------------------------------------------------------------
//

//
// ------------------------------------ INTERNAL FSM ---------------------------------------------
reg [2:0] fsm_state;
reg [2:0] n_fsm_state;

localparam FSM_IDLE  = 0;
localparam FSM_START = 1;
localparam FSM_RECV  = 2;
localparam FSM_STOP  = 3;
//------------------------------------------------------------------------------------------------
//

//
//------------------------------------- INTERNAL REGS --------------------------------------------
reg [                4:0] bit_cnt;
reg [PAYLOAD_BITS - 1:0 ] data_to_send;
reg [PAYLOAD_BITS - 1:0 ] data_to_receive;

reg                       trailing_edge_reg;
reg                       leading_edge_reg;
reg                       spi_clk_reg;
//-------------------------------------------------------------------------------------------------
//

//
// -------------------------------------- INTERNAL WIRES --------------------------------------
wire start_transaction  = spi_en & ~spi_cs;

wire save_bit           = CPHA ? (trailing_edge_reg    )  : (leading_edge_reg);
wire put_bit            = CPHA ? (leading_edge_reg     )  : (trailing_edge_reg);
wire end_of_transaction = (bit_cnt  == PAYLOAD_BITS - 1)  & (trailing_edge_reg);
// ---------------------------------------------------------------------------------------------
//

//
// --------------------------------------- OUTPUT ASSIGNEMENT ---------------------------------
assign spi_miso         = data_to_send[PAYLOAD_BITS - 1 - bit_cnt];
// ---------------------------------------------------------------------------------------------
//

//
//------------------------------------- FSM NEXT STATE SELECTION -------------------------------
always @(*) begin : p_n_fsm_state
    case(fsm_state)
      FSM_IDLE    : n_fsm_state     = start_transaction ? FSM_START : FSM_IDLE;
      FSM_START   : n_fsm_state     = save_bit          ? FSM_RECV  : FSM_START;
      FSM_RECV    : n_fsm_state     = (rx_complete)     ? FSM_IDLE  : FSM_RECV;
      default: n_fsm_state = FSM_IDLE;
    endcase
end
//----------------------------------------------------------------------------------------------
//

//
//------------------------------------ PROGRESSES FSM STATE ----------------------------------------
always_ff @(posedge clk) begin : p_fsm_state
    if(rst) 
        fsm_state <= FSM_IDLE;
    else 
        fsm_state <= n_fsm_state;
end
//---------------------------------------------------------------------------------------------------
//

//
//--------------------------------------- EDGE DETECTOR -------------------------------------------
edge_detector #
(
    .CPOL(CPOL)
)
i_edge_detector
(
    .clk            (   clk            ),
    .signal         (   spi_clk        ),
    .positive_edge  (leading_edge_reg  ),
    .negative_edge  (trailing_edge_reg )
);
//
//------------------------------------- SPI BIT COUNTER -------------------------------------------
always_ff @(posedge clk) begin : p_bit_counter
    if(rst) 
        bit_cnt <= 'b0;
    else
    begin
        bit_cnt <= bit_cnt;

        // Skips 1 clock for falling edges
        if(end_of_transaction | (fsm_state == FSM_START & CPHA))
            bit_cnt <= 'b0;
        else if (put_bit)
            bit_cnt <= bit_cnt + 1'b1;
    end
end
//--------------------------------------------------------------------------------------------------
//

//
//---------------------------------------- LATCHES THE DATA -----------------------------------------
always_ff @(posedge clk) begin : p_txd_reg
    if(rst) 
        data_to_send <= 'b0;
    else
    begin
        data_to_send <= data_to_send;

        if(fsm_state == FSM_IDLE && n_fsm_state == FSM_START)
            data_to_send <= spi_miso_data;
    end
end
//----------------------------------------------------------------------------------------------------
//

//
//-------------------------------------- RECEIVE DATA FROM MASTER -------------------------------------
always_ff @(posedge clk) begin : p_rxd_reg
    if(rst)
    begin
        spi_mosi_data   <= 'b0;
        data_to_receive <= 'b0;
    end 
    else
    begin
        spi_mosi_data   <= spi_mosi_data;
        data_to_receive <= data_to_receive;

        if (end_of_transaction)
        begin
            spi_mosi_data   <= {data_to_receive[PAYLOAD_BITS - 1:1], spi_mosi};
            data_to_receive <= 'b0;
        end
        else if (save_bit)
                data_to_receive [PAYLOAD_BITS - 1 - bit_cnt] <= spi_mosi;
    end
end
//---------------------------------------------------------------------------------------------------
//

//
//----------------------------------- PAYLOAD DONE ---------------------------------------------------
always_ff @(posedge clk)
begin
    if (rst) 
        rx_complete <= 0;
    else 
        rx_complete <= end_of_transaction;
end
//----------------------------------------------------------------------------------------------------
//

endmodule