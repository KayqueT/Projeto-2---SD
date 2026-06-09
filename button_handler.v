module button_handler (
    input wire clk,
    input wire btn_in,
    output reg pulse_out = 0
);

    reg sync_0 = 1;
    reg sync_1 = 1;
    reg [19:0] counter = 0;
    reg btn_stable = 1;
    reg btn_stable_prev = 1;

    always @(posedge clk) begin
        sync_0 <= btn_in;
        sync_1 <= sync_0;
    end

    always @(posedge clk) begin
        if (sync_1 == btn_stable) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
            if (counter == 20'hFFFFF) begin 
                btn_stable <= sync_1;
            end
        end
    end

    always @(posedge clk) begin
        btn_stable_prev <= btn_stable;
        if (btn_stable_prev == 1'b0 && btn_stable == 1'b1) begin
            pulse_out <= 1'b1;
        end else begin
            pulse_out <= 1'b0;
        end
    end
endmodule