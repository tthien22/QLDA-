`timescale 1ns / 1ps

module PE_Region_Growing_tb #(
 parameter 
    hex_infile = "D:\\NoC\\ima\\image\\image_273x182.hex", 
    hex_outfile = "D:\\NoC\\ima\\image\\output.hex",
    rows = 273,
    cols = 182,
    size = rows * cols,
    
    X=3,
    Y=3,

    id_width=2,
    data_width=24,
    pkt_no_field_size=4,
    x_size=$clog2(X),
    y_size=$clog2(Y),

    total_width = x_size + y_size + pkt_no_field_size + id_width + data_width
    )();
  // Inputs
  reg clk;
  reg rstn;

  reg r_valid_pe;
  reg [33:0] r_data_pe;
  reg w_ready_pe;

  // Outputs
  wire r_ready_pe;
  wire w_valid_pe;
  wire [total_width-1:0] w_data_pe;

  wire [1:0] state_monitor;
  wire [15:0] write_address;
  wire [15:0] read_address;
  wire [8:0] write_address_rows;
  wire [8:0] write_address_cols;
  wire [8:0] read_address_rows;
  wire [8:0] read_address_cols;

reg [7:0] memory [rows-1:0][cols-1:0][2:0];                          //making a vector of type 'reg' for storing data from input hex file
reg [15:0] i = 0;
integer k = 0,f,x,y;

  // Instantiate the Unit Under Test (UUT)
  PE_Region_Growing uut (
    .clk(clk),
    .rstn(rstn),
    .r_ready_pe(r_ready_pe),
    .r_valid_pe(r_valid_pe),
    .r_data_pe(r_data_pe),
    .w_valid_pe(w_valid_pe),
    .w_ready_pe(w_ready_pe),
    .w_data_pe(w_data_pe),
    .state_monitor(state_monitor),
    .write_address(write_address),
    .read_address(read_address),
    .write_address_rows(write_address_rows),
    .write_address_cols(write_address_cols),
    .read_address_rows(read_address_rows),
    .read_address_cols(read_address_cols)
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;

  // Test sequence
  initial begin
    // Initialize Inputs
    rstn = 0;
    r_valid_pe = 0;
    r_data_pe = 0;

    // Reset the module
    #10 rstn = 1;

    // Test case: Write input packages

    // Send head package
    wait (r_ready_pe == 1)                        // each pixel has three values one for each color (RGB
      r_data_pe = {10'b0, 24'hFF_AA_BB}; // Head package
          r_valid_pe = 1;
          #20;
          r_valid_pe = 0;
          #10;
        
    // Send body packages
		f = $fopen(hex_outfile,"w");                          //opening the output hex file
		$readmemh(hex_infile,memory);                         //reading the input hex file and storing it's values in the vector 'memory'

		for(x = 0;x<rows;x=x+1) begin
			for(y = 0;y<cols;y=y+1) begin
        wait (r_ready_pe == 1)                        // each pixel has three values one for each color (RGB)
          r_data_pe = {10'b01, memory[x][y][0], memory[x][y][1], memory[x][y][2]}; // Body packages
          k = k+3;
          r_valid_pe = 1;
          #5;
          r_valid_pe = 0;
          #5;
		  end
    end
    // Send tail package
    wait (r_ready_pe == 1)                        // each pixel has three values one for each color (RGB)
    r_data_pe = {10'b11, 24'h44_55_66}; // Tail package
          r_valid_pe = 1;
          #20;
          r_valid_pe = 0;
          #10;
//WAIT FOR PROCESSING TO COMPLETE, THEN READ OUTPUT PACKAGES
    wait (state_monitor == 3)  
			for(x = 0;x<rows;x=x+1) begin
				for(y = 0;y<cols;y=y+1) begin                      // each pixel has three values one for each color (RGB)
          w_ready_pe = 1;
          wait (w_valid_pe == 1)  
          $fdisplay(f,"%2h",w_data_pe[23:16]);           //writing blue pixel values to output hex file
          $fdisplay(f,"%2h",w_data_pe[15:8]);           //writing green pixel values to output hex file
          $fdisplay(f,"%2h",w_data_pe[7:0]);           //writing red pixel values to output hex file\
          w_ready_pe = 0;
          #20;
			  end
      end
			$fclose(f);											        //closing the output hex file
      $finish;
  end
  // Monitor signals
  initial begin
    $monitor($time, " clk=%b rstn=%b state=%d r_ready_pe=%b r_valid_pe=%b r_data_pe=%h write_addr_rows=%d write_addr_cols=%d w_ready_pe =%b w_valid_pe=%b w_data_pe=%h read_addr_rows=%d addr_cols=%d", 
             clk, rstn, state_monitor, r_ready_pe, r_valid_pe, r_data_pe, write_address_rows, write_address_cols, w_ready_pe, w_valid_pe, w_data_pe, read_address_rows, read_address_cols);
  end

endmodule
