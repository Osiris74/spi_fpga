module spi_module_master # 
(
    parameter FREQUENCY    = 1_000_000,
    parameter CLK_HZ       = 50_000_000,

    parameter CPOL         = 0,
    parameter CPHA         = 0,

    parameter PAYLOAD_BITS = 8
)
(
    input  wire                     clk            , // Top level system clock input.
    input  wire                     rst            , // Asynchronous active low reset.
    input  wire                     spi_en         , // Start/stop signal SPI protocol
    input  wire                     spi_miso       , // Master input slave output input
    input  wire                     transmit_en    , // Start TX operation
    input  reg  [PAYLOAD_BITS -1:0] spi_mosi_data  , 
    
    output wire                     spi_clk        ,
    output wire                     spi_mosi       ,
    output wire                     spi_cs         ,
    output reg  [PAYLOAD_BITS-1:0]  spi_miso_data  ,
    output reg                      payload_done
);

// -------------------------------------------------------------------------- 
// Internal parameters.
// 

//
// Number of top clk cycles to transmit one bit
localparam  CYCLES_PER_BIT      = (CLK_HZ / FREQUENCY);

//
// Size of the registers which store sample counts and bit durations.
localparam  COUNT_REG_LEN  = 1+$clog2(CYCLES_PER_BIT);

//------------------------------------------------------------------------------------------------
//

//
// ------------------------------------ INTERNAL FSM ---------------------------------------------
reg [2:0] fsm_state;
reg [2:0] n_fsm_state;

localparam FSM_IDLE = 0;
localparam FSM_START= 1;
localparam FSM_SEND = 2;
localparam FSM_STOP = 3;
//------------------------------------------------------------------------------------------------
//

//
//------------------------------------- INTERNAL REGS --------------------------------------------
reg [COUNT_REG_LEN - 1:0] clk_cnt;
reg [                4:0] bit_cnt;
reg [PAYLOAD_BITS  - 1:0] data_to_send;
reg [PAYLOAD_BITS  - 1:0] data_to_receive;

reg                       spi_clk_reg;

reg                       trailing_edge_reg;
reg                       leading_edge_reg;
//-------------------------------------------------------------------------------------------------
//

//
// -------------------------------------- INTERNAL WIRES --------------------------------------
wire start_transaction  = (spi_en & transmit_en);
wire save_bit           = CPHA ? (trailing_edge_reg   ) : (leading_edge_reg);
wire put_bit            = CPHA ? (leading_edge_reg    )  : (trailing_edge_reg);
wire end_of_transaction = (bit_cnt  == PAYLOAD_BITS -1) & (trailing_edge_reg);
// ---------------------------------------------------------------------------------------------
//

//
// --------------------------------------- OUTPUT ASSIGNEMENT ---------------------------------
assign spi_clk          = spi_clk_reg;
assign spi_cs           = ( (fsm_state == FSM_IDLE || payload_done) ) ? 'b1 : 'b0;
assign spi_mosi         = data_to_send[PAYLOAD_BITS - 1 - bit_cnt];
// ---------------------------------------------------------------------------------------------
//

//
//------------------------------------- FSM NEXT STATE SELECTION -------------------------------
always @(*) begin : p_n_fsm_state
    case(fsm_state)
      FSM_IDLE    : n_fsm_state     = start_transaction ? FSM_START : FSM_IDLE;
      FSM_START   : n_fsm_state     = put_bit           ? FSM_SEND  : FSM_START;
      FSM_SEND    : n_fsm_state     = (payload_done)    ? (start_transaction ? FSM_START : FSM_IDLE)  : FSM_SEND;
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
//------------------------------------------ SPI_CLK GENERATOR ---------------------------------
always_ff @(posedge clk) begin : p_cycle_counter
    if(rst | fsm_state == FSM_IDLE) 
    begin
        clk_cnt           <= 'b0;
        spi_clk_reg       <= CPOL;
    end
    else
    begin
        if (~payload_done)
        begin
            spi_clk_reg  <= spi_clk_reg;
            clk_cnt      <= clk_cnt + 1'b1;

            if(clk_cnt       == CYCLES_PER_BIT - 1)
            begin
                clk_cnt           <= 'b0;
                spi_clk_reg       <= ~spi_clk_reg;
            end
        end
        else
        begin
            clk_cnt           <= 'b0;
            spi_clk_reg       <= CPOL;
        end
    end
end
//
//-------------------------------------------------------------------------------------------------

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

        if(((fsm_state == FSM_IDLE) | (fsm_state == FSM_SEND)) & n_fsm_state == FSM_START)
            data_to_send <= spi_mosi_data;
    end
end
//----------------------------------------------------------------------------------------------------
//

//
//-------------------------------------- RECEIVE DATA FROM SLAVE -------------------------------------
always_ff @(posedge clk) begin : p_rxd_reg
    if(rst)
    begin
        spi_miso_data   <= 'b0;
        data_to_receive <= 'b0;
    end 
    else
    begin
        spi_miso_data   <= spi_miso_data;
        data_to_receive <= data_to_receive;

        if (end_of_transaction)
        begin
            spi_miso_data   <= {data_to_receive[PAYLOAD_BITS - 1:1], spi_miso};
            data_to_receive <= 'b0;
        end
        else if (save_bit)
                data_to_receive [PAYLOAD_BITS - 1 - bit_cnt] <= spi_miso;
    end
end
//---------------------------------------------------------------------------------------------------
//

//
//----------------------------------- PAYLOAD DONE ---------------------------------------------------
always_ff @(posedge clk)
begin
    if (rst) 
        payload_done <= 0;
    else 
        payload_done <= end_of_transaction;
end
//----------------------------------------------------------------------------------------------------
//

endmodule