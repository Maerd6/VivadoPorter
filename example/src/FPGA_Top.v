// this is a top module that is designed for RSA timing attack on FPGA
// target FPGA board: ML506
// user_clock: 100MHz
// rst_pin: SW7: CPU_RST
// txd_pin and rxd_pin use COM

module FPGA_Top(clk_in1_p, clk_in1_n, rst_pin, txd_pin, rxd_pin, led_run, led);
  input clk_in1_p, clk_in1_n, rst_pin;
  output txd_pin;
  input rxd_pin;
  output reg led_run;
  output reg led = 1;
  
  // clock, rest signals
  wire rst_h, rst_hw, rst_sw;  
  
  // uart signals
  reg xmitH;
  wire [7:0] xmit_dataH;
  wire xmit_doneH;
  wire [7:0] cmd_dataH;
  wire cmd_rdyH;
  
  // command module
  wire start;
  wire key_ready, Din_ready;
  wire state;
  
  // AES cypher module
  wire [127:0] key, Din, Dout;
  wire rdy,EncDec;
  
  // CoreCtrl module
  wire wr_en;
  wire [7:0] cypher_uart;
  
  // FIFO signals
  wire fifo_full, fifo_empty;
  reg start_tx; // first byte
  reg uart_rdy, pre_doneH;
  
  // DCM signals
  wire clk, clk_buf;
  
  //RSA enable
  wire EN;
  
  //counter for led_run
  reg [31:0]counter_led;
  
  /////////////////////////////////////////////////////////////////////
  // global reset signal: system resets on logical high level
  // hardware reset is from the board and software reset is a PC command
  /////////////////////////////////////////////////////////////////////
  assign rst_h = rst_hw | rst_sw; // global reset
  assign rst_hw = rst_pin; // hardware reset
//  assign rst_h = rst_pin;
  assign EN = 1;
  /////////////////////////////////////////////////////////////////////
  // module instatiations
  /////////////////////////////////////////////////////////////////////
  // the UART model: for communicating with PC host
  // clock freqency: 50MHz; baud rate: 115200
  uart RS232(.clk(clk),
             .rst_h(rst_h),
             
             // Transmitter
             .uart_XMIT_dataH(txd_pin),
             .xmitH(xmitH),
             .xmit_dataH(xmit_dataH),
             .xmit_doneH(xmit_doneH),
             
             // Receiver
             .uart_REC_dataH(rxd_pin),
             .rec_dataH(cmd_dataH),
             .rec_readyH(cmd_rdyH));
  
  // the command module: for processing commands sent from Host
  cmd_machine CMD_DATA(.clk(clk),
                       .rst_h(rst_h),
                       .cmd_data(cmd_dataH),
                       .cmd_rdy(cmd_rdyH),
                       .EncDec(EncDec),
                       .kout(key),
                       .dout(Din),
                       .key_ready(key_ready),
                       .din_ready(Din_ready),
                       .start(start),
                       .rst_sw(rst_sw));
  
  AES_Comp AES(.Kin(key), 
               .Din(Din), 
               .Dout(Dout), 
               .Krdy(key_ready), 
               .Drdy(Din_ready), 
               .EncDec(EncDec), 
               .RST(rst_h), 
               .EN(EN), 
               .CLK(clk),
               .Dvld(rdy));
                
  // core control logic
  CoreCtrl CTRL(.clk(clk),
                .rst_h(rst_h),
                .start(start),
                .cypher_in(Dout),
                .rdy(rdy),
                .wr_en(wr_en),
                .cypher_out(cypher_uart));
  
//  // the LFSR module for generating random numbers
//  // output from LFSR is used as plain text
//  lfsr32 RandNum(.clk(clk),
//                 .rst_h(rst_h),
//                 .lfsr_en(lfsr_en),
//                 .set_seed(set_seed),
//                 .rand_seed(seed),
//                 .lfsr(message));
  
  // the FIFO module for buffering runtime results
  FIFO DATA_BUF(.clk(clk),
					 .rst(rst_h),
					 .din(cypher_uart),
					 .wr_en(wr_en),
					 .rd_en(xmitH),
					 .dout(xmit_dataH),
					 .full(fifo_full),
					 .empty(fifo_empty));
  
  // the DCM module for clock generation
  // 50MHz: clock used for implementation, div = 2
  clk_wiz_0 CLK_Gen(.clk_in1_p(clk_in1_p),
				  .clk_in1_n(clk_in1_n),
                  .clk_out(clk),
                  .reset(rst_hw));                  
  
  // for test only
  // assign clk = clk_pin;
   
  /////////////////////////////////////////////////////////////////////
  // glue logic: fifo control
  /////////////////////////////////////////////////////////////////////  
  // send data to host  
  always @ (posedge clk or posedge rst_h)
  begin
    if(rst_h)
       start_tx <= 1;
     else begin
        if(start == 1)
         start_tx <= 1;
        else if(fifo_empty == 0 && start_tx == 1)
         start_tx <= 0;
	  end
  end
  
  always @ (posedge clk or posedge rst_h)
  begin
    if(rst_h)
       xmitH <= 0;
     else begin
        if(fifo_empty == 0 && start_tx == 1)
         xmitH <= 1;
        else if(fifo_empty == 0 && uart_rdy == 1)
         xmitH <= 1;
        else
         xmitH <= 0;
     end
  end
  
  // produce one clock cycle uart_rdy signal
  always @ (posedge clk or posedge rst_h)
  begin
    if(rst_h) begin
      uart_rdy <= 0;
      pre_doneH <= 0;
    end
    else begin
      if(xmit_doneH == 1 && pre_doneH == 0)
        uart_rdy <= 1; // lasts for one clock cycle
      else
		uart_rdy <= 0;
		pre_doneH <= xmit_doneH;
	 end
  end
  
  always @ (posedge clk or posedge rst_h)
  begin
    if(rst_h)begin
      counter_led <= 0;
	  led_run <= 1;
	end
	else if(counter_led == 50000000)begin
	  counter_led <= 0;
	  led_run <= ~led_run;
	end
	else
	  counter_led <= counter_led + 1;
  end
endmodule
