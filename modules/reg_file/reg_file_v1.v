module reg_file (
    input wire clk,
    input wire rst_n,
    input wire [4:0] rs1_addr,
    input wire [4:0] rs2_addr,
    output reg [31:0] rs1_data,
    output reg [31:0] rs2_data,
    input wire [4:0] waddr,
    input wire [31:0] wdata,
    input wire we
);

    // Register file storage (31 registers for x1-x31, x0 is hardwired to 0)
    reg [31:0] rf [1:31];

    // Extract bit-selects for use in combinational block
    wire [4:0] waddr_bits;
    assign waddr_bits = waddr;

    // Asynchronous read ports (combinational)
    // Read data is available immediately based on read address
    always @(*) begin
        // Read port 1
        if (rs1_addr == 5'd0) begin
            rs1_data = 32'h0;
        end else if (rs1_addr == waddr_bits && we) begin
            // Write-first behavior: if writing to same address, forward write data
            rs1_data = wdata;
        end else begin
            rs1_data = rf[rs1_addr[4:0]];
        end

        // Read port 2
        if (rs2_addr == 5'd0) begin
            rs2_data = 32'h0;
        end else if (rs2_addr == waddr_bits && we) begin
            // Write-first behavior: if writing to same address, forward write data
            rs2_data = wdata;
        end else begin
            rs2_data = rf[rs2_addr[4:0]];
        end
    end

    // Synchronous write port
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset: initialize all registers to zero
            integer i;
            for (i = 1; i <= 31; i = i + 1) begin
                rf[i] <= 32'h0;
            end
        end else begin
            // Write on positive clock edge when write enable is asserted
            // x0 (address 0) is hardwired to zero and ignores writes
            if (we && waddr != 5'd0) begin
                rf[waddr] <= wdata;
            end
        end
    end

endmodule