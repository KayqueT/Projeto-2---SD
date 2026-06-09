module button_handler (
    input wire clk,
    input wire btn_in,
    output reg pulse_out
);

    reg sync_0, sync_1;
    always @(posedge clk) begin
        sync_0 <= btn_in;
        sync_1 <= sync_0;
    end

    integer counter;
    reg btn_stable;

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

    reg btn_stable_prev;
    always @(posedge clk) begin
        btn_stable_prev <= btn_stable;
        if (btn_stable_prev == 1'b0 && btn_stable == 1'b1) begin
            pulse_out <= 1'b1;
        end else begin
            pulse_out <= 1'b0;
        end
    end
endmodule