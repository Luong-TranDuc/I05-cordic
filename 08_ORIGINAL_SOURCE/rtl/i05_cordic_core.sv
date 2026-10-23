module i05_cordic_core (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    input  logic [7:0] angle,

    output logic signed [7:0] sin_out,
    output logic signed [7:0] cos_out,
    output logic       busy,
    output logic       done
);

    localparam int F = 14;

    // 1/K_8 * 2^14 for the 8-iteration mentor proposal.
    localparam logic signed [15:0] X_INIT = 16'sd9949;

    logic signed [15:0] x_reg, y_reg;
    logic signed [15:0] x_next, y_next;
    logic signed [9:0]  z_reg, z_next;
    logic [3:0] count;

    logic sign_cos, sign_sin;
    logic signed [9:0] z_init;

    typedef enum logic [1:0] {
        S_IDLE,
        S_ITER,
        S_DONE
    } state_t;

    state_t state;

    function automatic logic signed [9:0] atan_const(input logic [2:0] idx);
        case (idx)
            3'd0: atan_const = 10'sd32;
            3'd1: atan_const = 10'sd19;
            3'd2: atan_const = 10'sd10;
            3'd3: atan_const = 10'sd5;
            3'd4: atan_const = 10'sd3;
            3'd5: atan_const = 10'sd1;
            3'd6: atan_const = 10'sd1;
            default: atan_const = 10'sd0;
        endcase
    endfunction

    function automatic signed [7:0] quantize_q14(
        input logic signed [15:0] v
    );
        logic signed [31:0] scaled;
        logic signed [31:0] q;
        begin
            // round(v / 2^14 * 128) = round(v / 2^7)
            if (v >= 0)
                scaled = v + 32'sd64;
            else
                scaled = v - 32'sd64;
            q = scaled >>> 7;

            if (q > 127)
                quantize_q14 = 8'sd127;
            else if (q < -128)
                quantize_q14 = -8'sd128;
            else
                quantize_q14 = q[7:0];
        end
    endfunction

    always_comb begin
        z_init    = '0;
        sign_cos  = 1'b0;
        sign_sin  = 1'b0;

        if (angle < 8'd64) begin
            z_init   = $signed({2'b00, angle});
            sign_cos = 1'b0;
            sign_sin = 1'b0;
        end else if (angle < 8'd128) begin
            z_init   = $signed({2'b00, (8'd128 - angle)});
            sign_cos = 1'b1;
            sign_sin = 1'b0;
        end else if (angle < 8'd192) begin
            z_init   = $signed({2'b00, (angle - 8'd128)});
            sign_cos = 1'b1;
            sign_sin = 1'b1;
        end else begin
            z_init   = $signed(10'd256 - {2'b00, angle});
            sign_cos = 1'b0;
            sign_sin = 1'b1;
        end

        if (z_reg >= 0) begin
            x_next = x_reg - (y_reg >>> count);
            y_next = y_reg + (x_reg >>> count);
            z_next = z_reg - atan_const(count[2:0]);
        end else begin
            x_next = x_reg + (y_reg >>> count);
            y_next = y_reg - (x_reg >>> count);
            z_next = z_reg + atan_const(count[2:0]);
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x_reg   <= '0;
            y_reg   <= '0;
            z_reg   <= '0;
            count   <= '0;
            sin_out <= '0;
            cos_out <= '0;
            busy    <= 1'b0;
            done    <= 1'b0;
            state   <= S_IDLE;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        x_reg <= X_INIT;
                        y_reg <= '0;
                        z_reg <= z_init;
                        count <= 4'd0;
                        busy  <= 1'b1;
                        state <= S_ITER;
                    end
                end

                S_ITER: begin
                    busy  <= 1'b1;
                    x_reg <= x_next;
                    y_reg <= y_next;
                    z_reg <= z_next;

                    if (count == 4'd7) begin
                        // sign restoration and output quantization use the
                        // post-iteration values.
                        cos_out <= sign_cos
                                   ? -quantize_q14(x_next)
                                   :  quantize_q14(x_next);
                        sin_out <= sign_sin
                                   ? -quantize_q14(y_next)
                                   :  quantize_q14(y_next);
                        busy  <= 1'b0;
                        state <= S_DONE;
                    end else begin
                        count <= count + 1'b1;
                    end
                end

                S_DONE: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
