module edge_detector #
(
    parameter CPOL = 0  
)
(
    input clk,
    input signal,
    output negative_edge,
    output positive_edge
);

logic int_detector;

always_ff @(posedge clk)
begin
    int_detector <= signal;
end

assign positive_edge = CPOL ? (int_detector  & ~signal) : (~int_detector &  signal);
assign negative_edge = CPOL ? (~int_detector &  signal) : (int_detector  & ~signal);

endmodule