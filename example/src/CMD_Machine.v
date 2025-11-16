// this is a command machine that processes the commands and data sent from the PC host

module cmd_machine(clk, rst_h, cmd_data, cmd_rdy, EncDec, kout, dout, key_ready, din_ready, start, rst_sw);
  input clk; // clock signal
  input rst_h; // the global reset signal
   
  input [7:0] cmd_data;
  input cmd_rdy;
  
  output reg [128:0] kout, dout;
  output key_ready, din_ready;
  output EncDec;
  output start; // start processing
  output rst_sw; // software reset

  // state machine states
  parameter IDLE = 4'h0; // idel state
  parameter RESET = 4'h1; 
  parameter START = 4'h2; 
  parameter RECVD = 4'h3; // receive date
  parameter SET_KEY = 4'hA;
  parameter SEND_KEY = 4'hB;
  parameter SET_DIN = 4'hE;
  parameter SEND_DIN = 4'hF;
  
  // commands
  parameter CMD_RESET = 8'h00;
  parameter CMD_ENC = 8'h05;
  parameter CMD_DEC = 8'h0A;
  parameter CMD_DATA = 8'h50;     //receive data from uart
  parameter CMD_SET_KEY  = 8'h55; //set key and store in reg
  parameter CMD_SEND_KEY  = 8'h5A; //send key to AES core
  parameter CMD_SET_DIN = 8'hA0;   //set Din and store in reg
  parameter CMD_SEND_DIN  = 8'hA5; //send Din to AES core
  
  // state machine
  reg [3:0] state;
  reg [127:0] recv_data;
  reg [127:0] key, din;
  reg EncDec;//en=0;de=1;
  reg start;
  reg rst_sw;
  reg [3:0] dcnt;
  
  // command recv process
  reg cmd_recv, pre_rdy;
  
  //out to control AES core
  reg key_ready;
  reg din_ready;
  
  // state machine
  always @(posedge clk or posedge rst_h)
  begin
    if(rst_h)      
      state <= IDLE;
    else begin
      case(state)
        // wait for command
        IDLE :  begin
                  if(cmd_recv == 1 && cmd_data == CMD_RESET)
                    state <= RESET;
                  else if(cmd_recv == 1 && cmd_data == CMD_DATA)
                    state <= RECVD;
                  else if(cmd_recv == 1 && cmd_data == CMD_SET_KEY)
                    state <= SET_KEY;
                  else if(cmd_recv == 1 && cmd_data == CMD_SET_DIN)
                    state <= SET_DIN;
                  else if(cmd_recv == 1 && cmd_data == CMD_SEND_KEY)
                    state <= SEND_KEY;
                  else if(cmd_recv == 1 && cmd_data == CMD_SEND_DIN)
                    state <= SEND_DIN;
                  else
                    state <= IDLE;
                end
        
        // the reset state
        RESET  :  state <= IDLE;
        
        // the start state
        START  :  state <= IDLE;
        
        // receive data
        RECVD  :   if(cmd_recv == 1 && dcnt == 0)
                       state <= IDLE;
                   
        // update key
        SET_KEY  : state <= IDLE;
                   
        SET_DIN :  state <= IDLE;
        
        //send key
        SEND_KEY  :  state <= IDLE;
        
        SEND_DIN  :  state <= START;
      endcase
    end
  end
  
  //set EncDec;
  always @(posedge clk or posedge rst_h)
  begin
    if(rst_h)
      EncDec <= 0;
    else if(cmd_recv == 1 && cmd_data == CMD_ENC && state == IDLE)
      EncDec <= 0;
    else if(cmd_recv == 1 && cmd_data == CMD_DEC && state == IDLE)
      EncDec <= 1;
    else EncDec <= EncDec;
  end
  
  // command machine signals assignments
  // the receive data signal
  always @(posedge clk or posedge rst_h)
  begin
    if(rst_h)
        dcnt <= 'd15;
    else if(cmd_recv == 1 && state == RECVD) 
        dcnt <= dcnt - 1;
    else dcnt <= dcnt;
  end
  
  always @(posedge clk or posedge rst_h)
  begin
    if(rst_h)
      recv_data <= 'b0;
    else if(cmd_recv == 1 && state == RECVD) 
      recv_data[dcnt*8+7 -:8] <= cmd_data;
    else recv_data <= recv_data;
  end
  
  //SET_KEY
  always @(posedge clk or posedge rst_h)
    begin
      if(rst_h)
        key <= 0;
      else if(state == SET_KEY)
        key <= recv_data;
    end

  //SET_DIN
  always @(posedge clk or posedge rst_h)
    begin
      if(rst_h)
        din <= 0;
      else if(state == SET_DIN)
        din <= recv_data;
    end
    
  //key_ready
  always @(posedge clk or posedge rst_h)
      begin
        if(rst_h)
          key_ready <= 0;
        else if(cmd_recv == 1 && cmd_data == CMD_SEND_KEY && state == IDLE)
          key_ready <= 1;
        else
          key_ready <= 0;
      end
  
  //din_ready
  always @(posedge clk or posedge rst_h)
    begin
      if(rst_h)
        din_ready <= 0;
      else if(cmd_recv == 1 && cmd_data == CMD_SEND_DIN && state == IDLE)
        din_ready <= 1;
      else
        din_ready <= 0;
    end
    
  //SEND_KEY
  always @(posedge clk or posedge rst_h)
    begin
      if(rst_h)
        kout <= 0;
      else if(cmd_recv == 1 && cmd_data == CMD_SEND_KEY && state == IDLE)
        kout <= key;
      else kout <= kout;
    end
      
  //SEND_DIN
  always @(posedge clk or posedge rst_h)
    begin
      if(rst_h)
        dout <= 0;
      else if(cmd_recv == 1 && cmd_data == CMD_SEND_DIN && state == IDLE)
        dout <= din;
      else dout <= dout;
    end
    
  // the soft reset signal: one clock cycle
  always @(posedge clk or posedge rst_h)
  begin
    if(rst_h)     
      rst_sw <= 0;
    else begin
      case(state)
        IDLE :  rst_sw <= 0;
        
        // the reset state
        RESET  :  rst_sw <= 1;
        default : rst_sw <= 0;
      endcase
    end
  end
  
  // the soft start signal: one clock cycle
  always @(posedge clk or posedge rst_h)
  begin
    if(rst_h)     
      start <= 0;
    else begin
      case(state)
        IDLE :  start <= 0;
        // the start state
        START  :  start <= 1; // start processing
        default : start <= 0;
      endcase
    end
  end
  
  // produce the single cycle cmd_recv signal
  // state machine
  always @(posedge clk or posedge rst_h)
  begin
    if(rst_h) begin
      cmd_recv <= 0;
      pre_rdy <= 0;
    end
    else begin
      if(cmd_rdy == 1 && pre_rdy == 0)
        cmd_recv <= 1;
      else
        cmd_recv <= 0;
        pre_rdy <= cmd_rdy;
    end
  end
  
endmodule
