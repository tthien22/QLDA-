module PE_Region_Growing #(
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
) (
    input clk,
    input rstn,
    output r_ready_pe,
    input r_valid_pe,
    input [total_width-1:0] r_data_pe,

    output reg w_valid_pe,
    input w_ready_pe,
    output reg [total_width-1:0] w_data_pe,

    output reg [ 1:0] state_monitor,
    output reg [15:0] write_address,
    output reg [15:0] read_address,
    output reg [8:0] write_address_rows,
    output reg [8:0] write_address_cols,
    output reg [8:0] read_address_rows,
    output reg [8:0] read_address_cols
);

    reg [8:0] seed_x, seed_y;
    reg [23:0] target_color; // Mau sac cua seed pixel
    reg [8:0] neighbor_x [7:0];
    reg [8:0] neighbor_y [7:0];
    integer dx [7:0];           // 8 toa do x lan can seed pixel
    integer dy [7:0];           // 8 toa do y lan can seed pixel
    reg [7:0] processed[rows-1:0][cols-1:0]; // Bien luu trang thai da xu ly
    
    reg [8:0] queue_x[rows*cols-1:0]; // Hang doi cac toa do x cua pixel chua xu ly
    reg [8:0] queue_y[rows*cols-1:0]; // Hang doi cac toa do y cua pixel chua xu ly
    integer queue_front = 0; // Vi tri dau cua hang doi
    integer queue_rear = 0;  // Vi tri cuoi cua hang doi
    reg [8:0] current_x;     // toa do pixel hien tai
    reg [8:0] current_y;     // toa do pixel hien tai
    reg done = 0;   // bien kiem tra giai thuat hoan tat
       
    reg [17:0] color_threshold = 18'd80; // Threshold cho do lech mau       
    reg [17:0] temp;
    integer i,j;
 
 
  reg [1:0] state;  // Seq part of the FSM
  reg [1:0] next_state;  // combo part of FSM

  parameter IDLE = 0, WRITE_MEMORY = 1, PROCESS_IMAGE = 2, EXPORT_PACKAGE = 3;

  
  reg [7:0] memory [rows-1:0][cols-1:0][2:0];     //tao 1 mang luu tru input anh hex
  reg [7:0] result [rows-1:0][cols-1:0][2:0];

  wire [x_size+y_size-1:0] xy_size = 0;
  wire [id_width + pkt_no_field_size-1:0] pckinfo_size = 0;
  assign r_ready_pe = 1'b1;

    initial begin
    // Gan toa do seed pixel dau tien la x=150 y=90
        seed_x = 8'd150;
        seed_y = 8'd90;
        done = 0;
        // Khoi tao ma tran anh ket qua output_memory voi gia tri mac dinh
        for (i = 0; i < rows; i = i + 1) 
        begin
            for (j = 0; j < cols; j = j + 1) 
            begin
                result[i][j][0] = 8'b00000000; // Gia tri R 
                result[i][j][1] = 8'b00000000; // Gia tri G 
                result[i][j][2] = 8'b00000000; // Gia tri B 
                processed[i][j] = 0;
            end
        end
    end
  //STATE TRANSITION
  always @(posedge clk) begin
    // If reset is asserted, go back to IDLE state
    if (!rstn) begin
      state <= IDLE;
      w_valid_pe <= 1'b0;
      write_address_rows <= 0;
      write_address_cols <= 0;
      read_address_rows <= 0;
      read_address_cols <= 0;
    end  // Else transition to the next state
    else begin
      w_valid_pe <= 1'b0;
      state <= next_state;
      state_monitor <= state;
    end
  end


  //STATE LOGIC
  always @(*) begin
    case (state)
      //??i package input. IDLE
      IDLE: begin
        if (r_valid_pe & r_ready_pe) begin
          if (r_data_pe[25:24] == 2'b00) begin
            //Neu package là head, chuyen sang state ghi vào bo nho. WRITE_MEMORY
            next_state = WRITE_MEMORY;
          end
        end
      end

      // State ghi vào bo nho. WRITE_MEMORY
      WRITE_MEMORY: begin
        if (r_valid_pe & r_ready_pe) begin
          //Neu package là body, ghi data vào memory, dong thoi tang bien dem dia chi WRITE_MEMORY
          if (r_data_pe[25:24] == 2'b01) begin
            memory[write_address_rows][write_address_cols][0] = r_data_pe[23:16]; // Gia tri R 
            memory[write_address_rows][write_address_cols][1] = r_data_pe[15:8]; // Gia tri G 
            memory[write_address_rows][write_address_cols][2] = r_data_pe[7:0]; // Gia tri B
            if (write_address_cols == cols - 1) begin 
                
                if (write_address_rows < rows - 1) begin
                write_address_rows = write_address_rows + 1;
                write_address_cols = 0;
                end
            end else if (write_address_cols < cols - 1)begin
            write_address_cols = write_address_cols + 1;
            end
          end
          //Neu package là tail, chuyen sang state xu ly anh. PROCESS_IMAGE
          if (r_data_pe[25:24] == 2'b11) begin
            next_state = PROCESS_IMAGE;
          end
        end
      end

      // State xu ly anh, doi tín hieu process_done kích lên. PROCESS_IMAGE if (process_done) EXPORT_PACKAGE
      PROCESS_IMAGE: begin
        if (queue_front == queue_rear && done == 0) begin
                current_x = seed_x;
                current_y = seed_y;
                processed[current_x][current_y] = 1;
                done = 1;
                $display("queue_front =%d , queue_rear =%d", queue_front, queue_rear);                
            end
            else begin
                // Neu pixel co trong hang doi, lay pixel tiep theo
                if (queue_front < queue_rear) begin
                    current_x = queue_x[queue_front];
                    current_y = queue_y[queue_front];
                    queue_front = queue_front + 1;
                    $display("queue_front =%d , queue_rear =%d", queue_front, queue_rear);
                    //$display("queue_front =%d , queue_rear =%d", queue_front, queue_rear);
            end
            
        end
         
        // Lay 8 pixel lan can
        dx[0] = -1; dx[1] = 0; dx[2] = 1; dx[3] = 0; dx[4] = -1; dx[5] = -1; dx[6] = 1; dx[7] = 1;
        dy[0] = 0; dy[1] = -1; dy[2] = 0; dy[3] = 1; dy[4] = -1; dy[5] = 1; dy[6] = -1; dy[7] = 1;
        for (i = 0; i < 8; i = i + 1) begin
            neighbor_x[i] = current_x + dx[i];
            neighbor_y[i] = current_y + dy[i];
        end
             
        // Lay 3 mau pixel hien tai lam chuan muc tieu de so sanh
        target_color[23:16] = memory[current_x][current_y][0]; // R
        target_color[15:8] = memory[current_x][current_y][1]; // G
        target_color[7:0] = memory[current_x][current_y][2]; // B
         
        for (i = 0; i < 8; i = i + 1) 
        begin            
            if (neighbor_x[i] >= 0 && neighbor_x[i] < rows &&
                neighbor_y[i] >= 0 && neighbor_y[i] < cols &&
                processed[neighbor_x[i]][neighbor_y[i]] == 0) 
            begin
                
                // temp la binh phuong do chenh lech mau giua 2 pixel neighbor va pixel target    
                temp = (memory[neighbor_x[i]][neighbor_y[i]][0] - target_color[23:16]) * (memory[neighbor_x[i]][neighbor_y[i]][0] - target_color[23:16]) +   //R different
                       (memory[neighbor_x[i]][neighbor_y[i]][1] - target_color[15:8]) * (memory[neighbor_x[i]][neighbor_y[i]][1] - target_color[15:8]) +   //G different
                       (memory[neighbor_x[i]][neighbor_y[i]][2] - target_color[7:0]) * (memory[neighbor_x[i]][neighbor_y[i]][2] - target_color[7:0]);    //B different
                    
                    // so sanh binh phuong do lech mau voi threshold
                    if ( temp < (color_threshold*color_threshold) )
                    begin
                        processed[neighbor_x[i]][neighbor_y[i]] = 1;
                            
                        //Sao chep pixel sang anh dau ra da duoc khoi tao mac dinh o tren
                        result[neighbor_x[i]][neighbor_y[i]][0] = memory[neighbor_x[i]][neighbor_y[i]][0];
                        result[neighbor_x[i]][neighbor_y[i]][1] = memory[neighbor_x[i]][neighbor_y[i]][1];
                        result[neighbor_x[i]][neighbor_y[i]][2] = memory[neighbor_x[i]][neighbor_y[i]][2];
                        $display ("result[%d][%d][0]=%2h",neighbor_x[i],neighbor_y[i],result[neighbor_x[i]][neighbor_y[i]][0]);
                        $display ("result[%d][%d][1]=%2h",neighbor_x[i],neighbor_y[i],result[neighbor_x[i]][neighbor_y[i]][1]);
                        $display ("result[%d][%d][2]=%2h",neighbor_x[i],neighbor_y[i],result[neighbor_x[i]][neighbor_y[i]][2]);
                        // Them pixel lang gieng vao hang doi de xu ly tiep
                        queue_x[queue_rear] = neighbor_x[i];
                        queue_y[queue_rear] = neighbor_y[i];
                        queue_rear  = queue_rear + 1;
                    end
                    
                    if(temp >= (color_threshold*color_threshold))
                    begin
                        processed[neighbor_x[i]][neighbor_y[i]] = 1;
                    end                        
              end
        end
        if(queue_front == queue_rear && done == 1)begin
        next_state   = EXPORT_PACKAGE;
        read_address_rows = 0;
        read_address_cols = 0;
        end
        
      end

      // Khi nh?n ???c tín hi?u process_done, chuy?n sang state ??c output_memory và g?i ra w_data_pe thành các package
      EXPORT_PACKAGE: begin
        if (w_ready_pe) begin
          w_data_pe = {4'b0000, pckinfo_size, result[read_address_rows][read_address_cols][0],result[read_address_rows][read_address_cols][1],result[read_address_rows][read_address_cols][2]};
          
          //w_data_pe = {4'b0000, pckinfo_size, output_memory[read_address]};
          w_valid_pe = 1'b1;
          //read_address = read_address + 1;
          
          if (read_address_cols == cols - 1) begin 
                read_address_cols = 0;
                if (read_address_rows < rows - 1) begin
                read_address_rows = read_address_rows + 1;
                end
          end else if (read_address_cols < cols - 1)begin
                read_address_cols = read_address_cols + 1;
          end
          
        end else if (read_address_cols == write_address_cols && read_address_rows == write_address_rows) begin
          next_state = IDLE;
        end
      end
    endcase
  end //end always


  
endmodule
