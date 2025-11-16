// *********************************************
//
// UART.v
//
// www.cmosexod.com
// 4/13/2001 (c) 2001
// Jeung Joon Lee
//
// Universal Asyhnchronous Receiver, Transmitter
// This is a reduced version of the UART.
// It is fully functional, synthesizable, ideal
// for embedded system.
//
// Update Log:
// 7/30/01  The 'bitCell_cntrH' compare in r_WAIT
//          state of u_rec.v has been changed from
//          the incorrect F to E.
//          The 'bitCell_cntrH' compare in x_WAIT
//          state of u_xmit.v has been changed from
//          the incorrect F to E.
// *********************************************

module uart (clk,
             rst_h,
             
             // Transmitter
             uart_XMIT_dataH,
             xmitH,
             xmit_dataH,
             xmit_doneH,
             
             // Receiver
             uart_REC_dataH,
             rec_dataH,
             rec_readyH);
  
  input  clk;
  input  rst_h;

  // Trasmitter
  output uart_XMIT_dataH;
  input  xmitH;
  input  [7:0] xmit_dataH;
  output xmit_doneH;

  // Receiver
  input  uart_REC_dataH;
 	output [7:0] rec_dataH;
  output rec_readyH;

  wire  uart_clk;
  wire  [7:0] rec_dataH;
  wire  rec_readyH;

  // the following logic was installed
  // to allow for xmit to be only a single
  // system clock cycle high.
  reg xmit_extender1, xmit_extender2;
  wire xmit_extender;
  reg xmit_extender_reset;
  reg rising_edge;
  reg first_re;
  reg second_re;
  reg baud_clk_delayed;

  always @(posedge clk)
    if (rst_h) xmit_extender1 <= 1'b0;
    else if (xmitH) xmit_extender1 <= 1'b1;
    else if (xmit_extender_reset) xmit_extender1 <= 1'b0;
    else xmit_extender1 <= xmit_extender1;

  always @(posedge clk)
    if(rst_h) xmit_extender_reset <= 1;
    else if(second_re & xmit_extender1) xmit_extender_reset <= 1;
    else xmit_extender_reset <= 0;

  always @(posedge clk)
    baud_clk_delayed <= uart_clk;

  always @(uart_clk or baud_clk_delayed)
    rising_edge <= uart_clk & !baud_clk_delayed;

  always @(posedge clk)
    if (rst_h) first_re <= 1'b0;
    else if (rising_edge & xmit_extender1 & !first_re) first_re <= 1'b1;
    else if (rising_edge & xmit_extender1 & second_re) first_re <= 1'b0;
    else first_re <= first_re;

  always @(posedge clk)
    if (rst_h) second_re <= 1'b0;
    else if (rising_edge & xmit_extender1 & first_re & !second_re) second_re <= 1'b1;
    else if (rising_edge & second_re) second_re <= 1'b0;
    else second_re <= second_re;
      
  always @(posedge uart_clk)
    if(rst_h) xmit_extender2 <= 0;
    else xmit_extender2 <= xmit_extender1;
      
  assign xmit_extender = xmit_extender1 | xmit_extender2;

  // Instantiate the Transmitter
  u_xmit  iXMIT(.clk(uart_clk),
                .rst_h(rst_h),
                
                // uart tx
                .uart_xmitH(uart_XMIT_dataH),
                
                //.xmitH(xmitH),
                .xmitH(xmit_extender),
                .xmit_dataH(xmit_dataH),
                .xmit_doneH(xmit_doneH));


  // Instantiate the Receiver
  u_rec iRECEIVER (.clk(uart_clk),
                   .rst_h(rst_h),                   

                   // uart rx
                   .uart_dataH(uart_REC_dataH),

                   .rec_dataH(rec_dataH),
                   .rec_readyH(rec_readyH));


  // Instantiate the Baud Rate Generator
  baud iBAUD(.clk(clk),
             .rst_h(rst_h),         
             .baud_clk(uart_clk));

endmodule

// *********************************************
// U_REC.v
//
// www.cmosexod.com
// 4/13/2001 (c) 2001
// Jeung Joon Lee
//
// This is the receiver portion of the UART
// *********************************************

module u_rec(clk,
             rst_h,

             // uart rx
             uart_dataH,
             
             
// recv data
             rec_dataH,
             rec_readyH);

  // Receiver state definition
  parameter	r_START 	= 3'b001,
          	 r_CENTER	= 3'b010,
          	 r_WAIT  	= 3'b011,
          	 r_SAMPLE	= 3'b100,
		  	     r_STOP  	= 3'b101;

  // Common parameter Definition
  parameter	LO = 1'b0,
          	 HI	= 1'b1,		
 		  	     X		= 1'bx;


  // *****************************
  // Receiver Configuration
  // *****************************

  // Word length.  
  // This defines the number of bits 
  // in a "word".  Typcially 8.
  // min=0, max=8
  parameter	WORD_LEN = 8;

  // ******************************************
  // PORT DEFINITIONS
  // ******************************************
  input rst_h;      // async reset
  input clk;        // main clock must be 16 x Baud Rate

  input uart_dataH;     // goes to the UART pin

  output [7:0] rec_dataH; // parallel received data
  output rec_readyH;      // when high, new data is ok to be read

  // ******************************************
  // MEMORY ELEMENT DEFINITIONS
  // ******************************************
 	reg [2:0] next_state, state;
  reg rec_datH, rec_datSyncH;
  reg [3:0] bitCell_cntrH;
  reg cntr_resetH;
  reg [7:0] par_dataH;
  reg shiftH;
  reg [3:0] recd_bitCntrH;
  reg countH;
  reg rstCountH;
  reg rec_readyH;
  reg rec_readyInH;

  wire    [7:0]   rec_dataH;

  assign rec_dataH = par_dataH;

  // synchronize the asynchrnous input
  // to the system clock domain
  // dual-rank
  always @(posedge clk or posedge rst_h)
    if (rst_h) begin
      rec_datSyncH <= 1;
      rec_datH     <= 1;
    end
    else begin
      rec_datSyncH <= uart_dataH;
      rec_datH     <= rec_datSyncH;
    end


  // Bit-cell counter
  always @(posedge clk or posedge rst_h)
    if (rst_h) bitCell_cntrH <= 0;
    else if (cntr_resetH) bitCell_cntrH <= 0;
    else bitCell_cntrH <= bitCell_cntrH + 1;


  // Shifte Register to hold the incoming
  // serial data
  // LSB is shifted in first
  always @(posedge clk or posedge rst_h)
    if (rst_h) par_dataH <= 0;
   	else if(shiftH) begin
      par_dataH[6:0] <= par_dataH[7:1];
      par_dataH[7]   <= rec_datH;
    end


  // RECEIVED BIT Counter
  // This coutner keeps track of the number of
  // bits received
  always @(posedge clk or posedge rst_h)
    if (rst_h) recd_bitCntrH <= 0;
    else if (countH) recd_bitCntrH <= recd_bitCntrH + 1;
   	else if (rstCountH) recd_bitCntrH <= 0;


  // State Machine - Next State Assignment
  always @(posedge clk or posedge rst_h)
    if (rst_h) state <= r_START;
    else state <= next_state;


  // State Machine - Next State and Output Decode
  always @(state or rec_datH or bitCell_cntrH or recd_bitCntrH)
  begin
    // default
    next_state  = state;
    cntr_resetH = HI;
    shiftH      = LO;
    countH      = LO;
    rstCountH   = LO;
    rec_readyInH= LO;

    case (state)    
    // START
    // Wait for the start bit
    r_START: begin
              if (~rec_datH ) next_state = r_CENTER;
              else begin
                next_state = r_START;
                rstCountH  = HI; // place the bit counter in rst state
                rec_readyInH = LO; // by default, we're ready
              end
            end

    // CENTER
    // Find the center of the bit-cell
    // A bit cell is composed of 16 system-clock
    // ticks
    r_CENTER: begin
                if (bitCell_cntrH == 4'h4) begin
                  // if after having waited 1/2 bit cell,
                  // it is still 0, then it is a genuine start bit
                  if (~rec_datH) next_state = r_WAIT;
                    // otherwise, could have been a false noise
                  else next_state = r_START;
        	       end 
        	       else begin
                  next_state  = r_CENTER;
                  cntr_resetH = LO;  // allow counter to tick         
                end
              end

    // WAIT
    // Wait a bit-cell time before sampling the
    // state of the data pin
    r_WAIT: begin
              if (bitCell_cntrH == 4'hE) begin
                if (recd_bitCntrH == WORD_LEN)
                  next_state = r_STOP; // we've sampled all 8 bits
                else
                  next_state = r_SAMPLE;
              end
              else begin
                next_state  = r_WAIT;
                cntr_resetH = LO;  // allow counter to tick
              end
            end

    // SAMPLE
    // Sample the state of the RECEIVE data pin
    r_SAMPLE: begin
                shiftH = HI; // shift in the serial data
                countH = HI; // one more bit received
                next_state = r_WAIT;
              end    


    // STOP
    // make sure that we've seen the stop
    // bit
    r_STOP: begin
              next_state = r_START;
              rec_readyInH = HI;
            end

    default: begin
              next_state    = 3'bxxx;
              cntr_resetH   = X;
              shiftH        = X;
            	 countH        = X;
              rstCountH     = X;
              rec_readyInH  = X;
            end

    endcase
  end


  // register the state machine outputs
  // to eliminate ciritical-path/glithces
  always @(posedge clk or posedge rst_h)
    if (rst_h) rec_readyH <= 0; // modified to 0 by Vinnie
    else rec_readyH <= rec_readyInH;

endmodule

// *********************************************
// U_XMIT.v
// This is the asynchronous transmitter
// portion of the UART
// *********************************************

module u_xmit(clk,
              rst_h,
              uart_xmitH,
              xmitH,
              xmit_dataH,
      	       xmit_doneH);

  // Xmitter state definition
  parameter	x_IDLE		= 3'b000,
			      x_START	= 3'b010,
			      x_WAIT		= 3'b011,
			      x_SHIFT	= 3'b100,
			      x_STOP		= 3'b101;

  parameter x_STARTbit = 2'b00,
			      x_STOPbit  = 2'b01,
			      x_ShiftReg = 2'b10;

  // Common parameter Definition
  	parameter	LO	= 1'b0,
  	          HI	= 1'b1,
 		         X		= 1'bx;

  // *****************************
  // Transmitter Configuration
  // *****************************

  // Word length.  
  // This defines the number of bits 
  // in a "word".  Typcially 8.
  // min=0, max=8
  parameter	WORD_LEN = 8;

  // ******************************************
  // PORT DEFINITIONS
  // ******************************************
  input clk;    // system clock. Must be 16 x Baud
  input rst_h;  // asynch reset

  output uart_xmitH;  // this pin goes to the connector
  input  xmitH;       // active high, Xmit command
  input  [7:0] xmit_dataH;  // data to be xmitted
  output xmit_doneH;  // status

  // ******************************************
  //
  // MEMORY ELEMENT DEFINITIONS
  //
  // ******************************************
  reg [2:0] next_state, state;
  reg load_shiftRegH;
  reg shiftEnaH;
  reg [4:0] bitCell_cntrH;
  reg countEnaH;
  reg [7:0] xmit_ShiftRegH;
  reg [3:0] bitCountH;
  reg rst_bitCountH;
  reg ena_bitCountH;
  reg [1:0] xmitDataSelH;
  reg uart_xmitH;
  reg xmit_doneInH;
  reg xmit_doneH;

  always @(xmit_ShiftRegH or xmitDataSelH)
    case (xmitDataSelH)
      x_STARTbit: uart_xmitH = LO;
      x_STOPbit:  uart_xmitH = HI;
      x_ShiftReg: uart_xmitH = xmit_ShiftRegH[0];
      default:    uart_xmitH = X; 
  endcase


  // Bit Cell time Counter
  always @(posedge clk or posedge rst_h)
    if (rst_h) bitCell_cntrH <= 0;
    else if (countEnaH) bitCell_cntrH <= bitCell_cntrH + 1;
    else bitCell_cntrH <= 0;

  // Shift Register
  // The LSB must be shifted out first
  always @(posedge clk or posedge rst_h)
    if (rst_h) xmit_ShiftRegH <= 0;
    else
      if (load_shiftRegH) xmit_ShiftRegH <= xmit_dataH;
      else if (shiftEnaH) begin
        xmit_ShiftRegH[6:0] <= xmit_ShiftRegH[7:1];
        xmit_ShiftRegH[7] <= HI;
      end
      else xmit_ShiftRegH <= xmit_ShiftRegH;


  // Transmitted bit counter
  always @(posedge clk or posedge rst_h)
    if (rst_h) bitCountH <= 0;
    else if (rst_bitCountH) bitCountH <= 0;
    else if (ena_bitCountH) bitCountH <= bitCountH + 1;


  // STATE MACHINE
  // State Variable
  always @(posedge clk or posedge rst_h)
    if (rst_h) state <= x_IDLE;
    else state <= next_state;

  // Next State, Output Decode
  always @(state or xmitH or bitCell_cntrH or bitCountH)
  begin  
    // Defaults
    next_state     = state;
    load_shiftRegH = LO;
    countEnaH      = LO;
    shiftEnaH      = LO;
    rst_bitCountH  = LO;
    ena_bitCountH  = LO;
    xmitDataSelH   = x_STOPbit;
    xmit_doneInH   = LO;

    case (state)
    // x_IDLE
    // wait for the start command
    x_IDLE: begin
              if (xmitH) begin
                next_state = x_START;
                load_shiftRegH = HI;
              end
              else begin
                next_state    = x_IDLE;
                rst_bitCountH = HI;
                xmit_doneInH  = HI;
              end
            end
    
    // x_START
    // send start bit
    x_START: begin
              xmitDataSelH    = x_STARTbit;
              if (bitCell_cntrH == 4'hF)
                next_state = x_WAIT;
              else begin
                next_state = x_START;
                countEnaH  = HI; // allow to count up
              end       
            end
    
    // x_WAIT
    // wait 1 bit-cell time before sending
    // data on the xmit pin
    x_WAIT: begin
              xmitDataSelH = x_ShiftReg;
              if (bitCell_cntrH == 4'hE) begin
                if (bitCountH == WORD_LEN) next_state = x_STOP;
                else begin
                  next_state = x_SHIFT;
                  ena_bitCountH = HI; //1more bit sent
                end
              // bit-cell wait not complete
              end
           	  else begin
                next_state = x_WAIT;
          	     countEnaH  = HI;
              end   
            end
    
    // x_SHIFT
    // shift out the next bit
    x_SHIFT: begin
              xmitDataSelH    = x_ShiftReg;
              next_state = x_WAIT;
              shiftEnaH  = HI; // shift out next bit
             end
    
    // x_STOP
    // send stop bit
    x_STOP: begin
              xmitDataSelH    = x_STOPbit;
        	     if (bitCell_cntrH == 4'hF) begin
                next_state   = x_IDLE;
                rst_bitCountH = HI; //1more bit sent
                xmit_doneInH = HI;
              end
              
else begin
                next_state = x_STOP;
                countEnaH = HI; //allow bit cell cntr
              end
            end
            
    default: begin
              next_state     = 3'bxxx;
              load_shiftRegH = X;
              countEnaH      = X;
              shiftEnaH      = X;
              rst_bitCountH  = X;
              ena_bitCountH  = X;
              xmitDataSelH   = 2'bxx;
              xmit_doneInH   = X;
            end
    endcase
  end


  // register the state machine outputs
  // to eliminate ciritical-path/glithces
  always @(posedge clk or posedge rst_h)
    if (rst_h) xmit_doneH <= 0;
    else xmit_doneH <= xmit_doneInH;

endmodule

// *********************************************
// BAUD.v
//
// www.cmosexod.com
// 4/13/2001 (c) 2001
// Jeung Joon Lee
//
// This is the "baud-rate-genrator"
// The "baud_clk" is the output clock feeding the
// receiver and transmitter modules of the UART.
//
// By design, the purpose of the "baud_clk" is to
// take in the "clk" and generate a clock
// which is 16 x BaudRate, where BaudRate is the
// desired UART baud rate. 
//
// Refer to "inc.h" for the setting of system clock
// and the desired baud rate.
// *********************************************

module baud(clk,
            rst_h,
               
            baud_clk);

  // The xtal-osc clock freq
  parameter XTAL_CLK = 50000000;

  // The desired baud rate
  parameter BAUD = 115200;
  parameter CLK_DIV = XTAL_CLK / (BAUD * 16 * 2);

  // CW >= log2(CLK_DIV)
  parameter CW = 5;

  input clk;
  input rst_h;
  output baud_clk;

  reg [CW-1:0] clk_div;
  reg baud_clk;

  always @(posedge clk or posedge rst_h)
    if (rst_h) begin
      clk_div  <= 0;
      baud_clk <= 0;
    end
    else if (clk_div == CLK_DIV) begin
      clk_div  <= 0;
      baud_clk <= ~baud_clk;
 	  end
    else begin
      clk_div  <= clk_div + 1;
      baud_clk <= baud_clk;
    end

endmodule
