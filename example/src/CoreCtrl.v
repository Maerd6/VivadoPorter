// this module control the running of the AES Core

module CoreCtrl(clk, rst_h, start, cypher_in, rdy, wr_en, cypher_out);
  input clk;
  input rst_h; // level high reset
  input start; // start processing
  input [127:0]cypher_in;//cypher from AES
  input rdy; // cypher text ready: encryption done
  output wr_en;
  output [7:0] cypher_out;
  
  // state machine states
  parameter IDLE = 4'h0; // idel state
  parameter LOAD = 4'h1; // load data to AES core
  parameter ENC = 4'h2; // encryption
  parameter STORE = 4'h3; //store 128 bits cypher in reg
  parameter SEND = 4'h4; // send data byte
  parameter STOP = 4'h5; // stop
  
  parameter MAX_NUM = 4000; // number of messages processed in a single run
  
  reg [2:0] state; // state machine state

  reg [31:0] counter; // message counter
  reg wr_en; // send cypher to FIFO
  reg [7:0] cypher_out; // cypher to FIFO
  reg [127:0] cypher_reg; //1024 bits cypher
  reg [3:0] out_counter;//counter for sending
  
  // state machine
  always @(posedge clk or posedge rst_h)
  begin
    if(rst_h)
      state <= IDLE;
    else begin
      case(state)
        // wait for command
        IDLE :  begin
                  if(start)
                    state <= LOAD;
                  else
                    state <= IDLE;
                end
        
        // the reset state
        LOAD :  state <= ENC;
        
        // the start state
        ENC :  begin
                 if(rdy)
                   state <= STORE;
                 else
                   state <= ENC;
                end
        
        // store data
        STORE :  state <= SEND;
        
        //send data
        SEND :  if(out_counter == 4'b1111)
                  state <= STOP;
                else state <= SEND;
        
        STOP :  state <= IDLE;
      endcase
    end
  end
  
  //store 128 bits cypher into reg
  always @(posedge clk or posedge rst_h)
  begin
    if(rst_h)
      cypher_reg <= 0;
    else if(state == STORE)
      cypher_reg <= cypher_in;
  end
  
  //out_counter
  always @(posedge clk or posedge rst_h)
  begin
    if(rst_h)
      out_counter <= 0;
    else if(state == SEND)
      out_counter <= out_counter + 1;
  end
  
  //send cypher to FIFO
  always @(posedge clk or posedge rst_h)
  begin
    if(rst_h)
      begin
        wr_en <= 0;
        cypher_out <= 0;
      end
    else if (state == SEND)
      begin
        wr_en <= 1;
        cypher_out <= cypher_reg[8*out_counter+7 -:8];
      end
    else wr_en <= 0;
  end

endmodule
