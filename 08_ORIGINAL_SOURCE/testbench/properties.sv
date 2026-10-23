`ifdef I05_SVA

assert done_pulse:
    assert property (@(posedge clk) done |=> !done);

assert no_unknowns:
    assert property (@(posedge clk)
        !((^({sin_out,cos_out,busy,done})) === 1'bx));

`endif
