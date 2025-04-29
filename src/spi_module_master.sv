module spi_module_master # 
(
    parameter FREQUENCY = 1_000_000,
    parameter CLK_HZ    = 50_000_000,

    parameter CPOL      = 0,
    parameter CPHA      = 0
)
(
    input  wire       clk            , // Top level system clock input.
    input  wire       rst            , // Asynchronous active low reset.
    input  wire       spi_en         , // Start/stop signal for SPI
    input  wire       spi_miso       , // Master input slave output input
    input  reg   [7:0] spi_mosi_data , 
    
    output wire       spi_clk        ,
    output wire       spi_mosi       ,
    output wire       spi_cs         ,
    output reg  [7:0] spi_miso_data  ,
    output reg        payload_done
);

// -------------------------------------------------------------------------- 
// Internal parameters.
// 

//
// Number of top clk cycles to transmit one bit
localparam  CYCLES_PER_BIT      = (CLK_HZ / FREQUENCY) * 2;

//
// Half of a number of clk
localparam  CYCLES_PER_HALF_BIT = CYCLES_PER_BIT / 2;

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
reg [                7:0] data_to_send;
reg [                7:0] data_to_receive;

reg                       spi_cs_reg;
reg                       spi_clk_reg;

reg                       trailing_edge_reg;
reg                       leading_edge_reg;
//-------------------------------------------------------------------------------------------------
//

//
// -------------------------------------- INTERNAL WIRES --------------------------------------
wire next_bit     = CPHA ? (leading_edge_reg && spi_en) : (trailing_edge_reg && spi_en);
wire end_of_transaction = (bit_cnt  == 7) && (next_bit);
// ---------------------------------------------------------------------------------------------
//

//
// --------------------------------------- OUTPUT ASSIGNEMENT ---------------------------------
assign spi_clk          = spi_clk_reg;
assign spi_cs           = (fsm_state == FSM_IDLE || payload_done) ? 'b1 : 'b0;
assign spi_mosi         = data_to_send [7 - bit_cnt];
//assign payload_done     = (bit_cnt  == 7) && (next_bit);
// ---------------------------------------------------------------------------------------------
//

//
//------------------------------------- FSM NEXT STATE SELECTION -------------------------------
always @(*) begin : p_n_fsm_state
    case(fsm_state)
      FSM_IDLE    : n_fsm_state     = spi_en         ? FSM_START : FSM_IDLE;
      FSM_START   : n_fsm_state     = next_bit       ? FSM_SEND  : FSM_SEND;
      FSM_SEND    : n_fsm_state     = (payload_done) ? FSM_IDLE  : FSM_SEND;
      default: n_fsm_state = FSM_IDLE;
    endcase
end
//----------------------------------------------------------------------------------------------
//

//
//------------------------------------ PROGRESSES FSM STATE ----------------------------------------
always_ff @(posedge clk) begin : p_fsm_state
    if(rst) 
    begin
        fsm_state <= FSM_IDLE;
    end
    else 
    begin
        fsm_state <= n_fsm_state;
    end
end
//---------------------------------------------------------------------------------------------------
//

//
//------------------------------------------ SPI_CLK GENERATOR ---------------------------------
always_ff @(posedge clk) begin : p_cycle_counter
    if(rst || !spi_en) 
    begin
        clk_cnt           <= 'b0;
        spi_clk_reg       <= CPOL;
        leading_edge_reg  <= 'b0;
        trailing_edge_reg <= 'b0;
    end
    else
    begin
        //if (fsm_state != FSM_IDLE)
        //begin
            leading_edge_reg  <= 'b0;
            trailing_edge_reg <= 'b0;
            clk_cnt <= clk_cnt + 1'b1;

            if(clk_cnt       == CYCLES_PER_BIT - 1)
            begin
                clk_cnt           <= 'b0;
                spi_clk_reg       <= ~spi_clk_reg;
                trailing_edge_reg <= 'b1;
            end
            else if (clk_cnt       == CYCLES_PER_HALF_BIT - 1)
            begin
                spi_clk_reg       <= ~spi_clk_reg;
                leading_edge_reg  <= 'b1;
            end
        //end
        /*else
            begin
                clk_cnt           <= 'b0;
                spi_clk_reg       <= CPOL;
                leading_edge_reg  <= 'b0;
                trailing_edge_reg <= 'b0;
            end
        */
    end
end
//
//-------------------------------------------------------------------------------------------------

//
//------------------------------------- SPI BIT COUNTER -------------------------------------------
always_ff @(posedge clk) begin : p_bit_counter
    if(rst || fsm_state != FSM_SEND) 
    begin
        bit_cnt <= 'b0;
    end 
    else
    begin
        bit_cnt <= bit_cnt;

        if(end_of_transaction)
        begin
            bit_cnt <= 'b0;
        end
        else if(next_bit) 
        begin
            bit_cnt <= bit_cnt + 1'b1;
        end
    end
end
//--------------------------------------------------------------------------------------------------
//

//
//---------------------------------------- LATCHES THE DATA -----------------------------------------
always_ff @(posedge clk) begin : p_txd_reg
    if(rst || !spi_en) 
    begin
        data_to_send <= 'b0;
    end 
    else
    begin
        data_to_send <= data_to_send;

        if(fsm_state == FSM_IDLE && n_fsm_state == FSM_START)
        begin
            data_to_send <= spi_mosi_data;
        end
    end
end
//----------------------------------------------------------------------------------------------------
//

//
//-------------------------------------- RECEIVE DATA FROM SLAVE -------------------------------------
always_ff @(posedge clk) begin : p_rxd_reg
    if(rst || !spi_en)
    begin
        spi_miso_data   <= 'b0;
        data_to_receive <= 'b0;
    end 
    else
    begin
        if (end_of_transaction)
        begin
            spi_miso_data   <= {data_to_receive[7:1], spi_miso};
            data_to_receive <= 'b0;
        end
        else
            spi_miso_data <= spi_miso_data;
        
        if (next_bit)
            data_to_receive [7-bit_cnt] <= spi_miso;
        else
            data_to_receive <= data_to_receive;
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