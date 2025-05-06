`timescale 1ns / 1ps

module tb_slave;

    // Parameters

    localparam CLK_HZ = 50_000_000;  // 50 MHz clock (20 ns period)
    localparam CLK_PERIOD = 1_000_000_000 / CLK_HZ;

    localparam FREQUENCY = 10_000_000; // 1 MHz SPI clock (1000 ns period)
    localparam SPI_PERIOD = 1_000_000_000 / FREQUENCY;

    // Signals
    logic       clk;
    logic       rst;
    logic       spi_en;
    logic       spi_miso;
    logic [7:0] spi_mosi_data;
    
    logic       spi_clk;
    logic       spi_mosi;
    logic       spi_cs;
    logic [7:0] spi_miso_data;

    logic       payload_done;
    logic       rx_complete ;


    logic [7:0] master_rx_data;
    logic [7:0] slave_rx_data;



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
        .rst            ( rst           ),
        .spi_en         ( spi_en        ),
        .spi_miso       ( spi_miso      ),
        .spi_mosi_data  ( spi_mosi_data ),
        .spi_clk        ( spi_clk       ),
        .spi_mosi       ( spi_mosi      ),
        .spi_cs         ( spi_cs        ),
        .spi_miso_data  ( master_rx_data),
        .payload_done   ( payload_done  )
    );

    spi_module_slave #(
        .FREQUENCY  ( FREQUENCY ),
        .CLK_HZ     ( CLK_HZ    ),
        .CPOL       (   0       ),
        .CPHA       (   0       )
    )
    i_spi_module_slave
    (
        .clk            ( clk           ),
        .rst            ( rst           ),
        .spi_en         ( spi_en        ),
        .spi_miso       ( spi_miso      ),
        .spi_mosi_data  ( slave_rx_data ),
        .spi_clk        ( spi_clk       ),
        .spi_mosi       ( spi_mosi      ),
        .spi_cs         ( spi_cs        ),
        .spi_miso_data  ( spi_miso_data ),
        .rx_complete    ( rx_complete   )
    );

    // Clock generation
    initial
    begin
        clk = 1'b0;

        forever
            # 5 clk = ~ clk;
    end

    integer passes = 0;
    integer fails  = 0;

    task spi_rcv_byte;
    integer i;
    logic [7:0] spi_master_received_data;
    logic [7:0] spi_slave_received_data;
        begin
            wait(spi_cs == 0);
            $display("CS asserted, starting transmission...");

            fork
                for(int i = 7; i >= 0; i--) 
                begin
                    @(posedge spi_clk);
                    spi_master_received_data[i] = spi_miso;
                end

                for(int j = 7; j >= 0; j--) 
                begin
                    @(posedge spi_clk)
                    spi_slave_received_data[i] = spi_mosi; 
                end

            join

            wait (payload_done == 1);
            
            if(master_rx_data !== spi_miso_data) 
            begin
                fails  = fails  + 1;
                $display("%d/%d/%d [FAIL] MASTER RX Expected %b and got %b", 
                        passes,fails,passes+fails,
                        spi_miso_data, master_rx_data);
            end
            else
            begin
                passes = passes + 1;
                $display("%d/%d/%d [PASS] MASTER RX Expected %b and got %b", 
                         passes,fails,passes+fails,
                         spi_miso_data, master_rx_data);
            end

            if(slave_rx_data !== spi_mosi_data) 
            begin
                fails  = fails  + 1;
                $display("%d/%d/%d [FAIL] SLAVE RX Expected %b and got %b", 
                        passes,fails,passes+fails,
                        spi_mosi_data, slave_rx_data);
            end
            else
            begin
                passes = passes + 1;
                $display("%d/%d/%d [PASS] SLAVE RX Expected %b and got %b", 
                         passes,fails,passes+fails,
                         spi_mosi_data, slave_rx_data);
            end
        end
    endtask



    // Main test sequence
    initial begin
        // Initialize inputs
        rst            = 0;
        spi_en         = 0;
        spi_mosi_data  = 0;
        
        // Reset sequence
        #10;
        rst = 1;
        #10;
        rst = 0;
        #10;
        
        // Test 1: Basic MOSI transmission
        $display("\nTest 1: MOSI Transmission");
        repeat (100)
        begin
            spi_mosi_data = $random;
            spi_miso_data = $random;
            spi_en = 1;
            spi_rcv_byte();
        end
        
        
        wait(spi_cs == 1);
        $display("MOSI transmission complete");
        spi_en = 0;
        #10;

        
        /*
        fork
            begin
                // Send test data on MISO
                wait(spi_cs == 0);
                for(int i = 7; i >= 0; i--) begin
                    @(posedge spi_clk); // Change data on rising edge
                    spi_miso = $random % 2;
                    $display("Sent MISO bit %d: %b", 7-i, spi_miso);
                end
            end
            begin
                // Receive verification
                wait(spi_cs == 1);
                $display("Received MISO data: 0x%h", spi_miso_data);
            end
        join
        */
        
        spi_en = 0;
        #200;

        /*

        // Test 3: Simultaneous MOSI/MISO
        $display("\nTest 3: Full Duplex Transfer");
        spi_en = 1;
        spi_mosi_data = 8'hC3;
        
        fork
            begin
                // Send MISO data
                wait(spi_cs == 0);
                for(int i = 7; i >= 0; i--) begin
                    @(posedge spi_clk);
                    spi_miso = i[0]; // Alternating 0/1
                end
            end
            begin
                // Verify MOSI
                wait(spi_cs == 0);
                for(int i = 7; i >= 0; i--) begin
                    @(negedge spi_clk);
                    if(spi_mosi !== spi_mosi_data[i]) begin
                        $error("MOSI error at bit %d", 7-i);
                    end
                end
            end
            begin
                // Verify MISO
                wait(spi_cs == 1);
                if(spi_miso_data !== 8'hAA) begin // Expected alternating bits
                    $error("MISO data error: Expected 0xAA, Got 0x%h", 
                          spi_miso_data);
                end
            end
        join

        */
        
        spi_en = 0;
        #200;

        $display("CYCLES/BIT    : %d"   , i_spi_module_master.CYCLES_PER_BIT);
    
        $display("Test Results:");
        $display("    PASSES: %d", passes);
        $display("    FAILS : %d", fails);
    
        $display("Finish simulation at time %d", $time);
        $stop;
    end

    /*
    // SPI clock frequency verification
    initial 
    begin
        realtime t1, t2;

        wait(spi_cs == 0);
        $display("\nSPI Frequency Verification");
        
        @(posedge spi_clk);
        t1 = $realtime;
        @(posedge spi_clk);
        t2 = $realtime;
        
        $display("Measured SPI period: %0.3f ns", t2 - t1);
        if($abs((t2 - t1) - SPI_PERIOD) > 10) 
        begin
            $error("SPI frequency out of spec!");
        end
    end

    */

    // Monitoring
    initial begin
        $timeformat(-9, 3, " ns", 8);
        //$monitor("At %t: CS=%b, SCK=%b, MOSI=%b, MISO=%b",
        //        $time, spi_cs, spi_clk, spi_mosi, spi_miso);
    end

endmodule