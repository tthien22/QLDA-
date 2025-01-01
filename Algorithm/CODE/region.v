`timescale 1ns / 1ps

module region#(parameter infile = "image_273x182.hex", outfile = "image_output.hex", rows = 273, cols = 182)   
(
    input clk,
    input rstn
    
    );
    reg [7:0] memory [rows-1:0][cols-1:0][2:0];     //tao 1 mang luu tru input anh file hex
    reg [7:0] result [rows-1:0][cols-1:0][2:0];
        
    integer i, j,
            f;
            
    reg [8:0] seed_x, seed_y;
    reg [23:0] target_color; // Mau sac cua seed pixel
    reg [8:0] neighbor_x [7:0];
    reg [7:0] neighbor_y [7:0];
    integer dx [8:0];           // 8 toa do x lan can seed pixel
    integer dy [7:0];           // 8 toa do y lan can seed pixel
    reg [7:0] processed[rows-1:0][cols-1:0]; // Bien luu trang thai da xu ly
    
    reg [8:0] queue_x[rows*cols-1:0]; // Hang doi cac toa do x cua pixel chua xu ly
    reg [7:0] queue_y[rows*cols-1:0]; // Hang doi cac toa do y cua pixel chua xu ly
    integer queue_front = 0; // Vi tri dau cua hang doi
    integer queue_rear = 0;  // Vi tri cuoi cua hang doi
    reg [8:0] current_x;     // toa do pixel hien tai
    reg [7:0] current_y;     // toa do pixel hien tai
    reg done = 0;   // bien kiem tra giai thuat hoan tat
       
    reg [17:0] color_threshold = 18'd80; // Threshold cho do lech mau       
    reg [17:0] temp;
    reg write=1;
    initial begin 
        $readmemh(infile,memory);       // Anh ban dau luu tru vao memory
        // Gan toa do seed pixel dau tien la x=150 y=90
        seed_x = 8'd150;
        seed_y = 8'd90;
        done = 0;
        // Khoi tao ma tran anh ket qua voi gia tri mac dinh
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
    
    always @(posedge clk)
        // Neu khong co pixel nao trong hang doi, su dung seed_x va seed_y
        begin
            if (queue_front == queue_rear && done == 0) begin
                current_x <= seed_x;
                current_y <= seed_y;
                $display("Processed Current [%d][%d]:%d",current_x,current_y,processed[current_x][current_y]);
                processed[current_x][current_y] <= 1;
                done <= 1;                
            end
            else begin
                // Neu pixel co trong hang doi, lay pixel tiep theo
                if (queue_front < queue_rear) begin
                    current_x = queue_x[queue_front];
                    current_y = queue_y[queue_front];
                    queue_front = queue_front + 1;
            end
        end
         
        // Lay 8 pixel lan can
        dx[0] = -1; dx[1] = 0; dx[2] = 1; dx[3] = 0; dx[4] = -1; dx[5] = -1; dx[6] = 1; dx[7] = 1;
        dy[0] = 0; dy[1] = -1; dy[2] = 0; dy[3] = 1; dy[4] = -1; dy[5] = 1; dy[6] = -1; dy[7] = 1;
        for (i = 0; i < 8; i = i + 1) begin
            neighbor_x[i] = current_x + dx[i];
            neighbor_y[i] = current_y + dy[i];    
        // Lay 3 mau pixel hien tai lam chuan muc tieu de so sanh
        target_color[23:16] = memory[current_x][current_y][0]; // R
        target_color[15:8] = memory[current_x][current_y][1]; // G
        target_color[7:0] = memory[current_x][current_y][2]; // B*/
         
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
                        // Them pixel lang gieng vao hang doi de xu ly tiep
                        queue_x[queue_rear] = neighbor_x[i];
                        queue_y[queue_rear] = neighbor_y[i];
                        queue_rear  = queue_rear + 1;;
                    end
                    
                    if(temp >= (color_threshold*color_threshold))
                    begin
                        processed[neighbor_x[i]][neighbor_y[i]] = 1;
                    end                        
             end
        end
        end
        if (queue_front == queue_rear && done == 1 && write == 1) begin
        f = $fopen(outfile,"w");  
            for (i = 0; i < rows; i = i + 1) 
            begin
                for (j = 0; j < cols; j = j + 1) 
                begin
                $fdisplay(f,"%2h",result[i][j][0]);
                $fdisplay(f,"%2h",result[i][j][1]);
                $fdisplay(f,"%2h",result[i][j][2]); 
                end
            end
            $fclose(f);
            $display ("Wirte output file complete!");
            write = 0;
         end
    end //end always
endmodule