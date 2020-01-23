
module cyclonev(

	input        clk_in,
	output       clk_out,

	input  [3:0] clk_bus_in,
	output [3:0] clk_bus_out,

	input        lvds_in,
	output       lvds_out,

	input  [3:0] lvds_bus_in,
	output [3:0] lvds_bus_out
);

assign clk_out      = clk_in;
assign clk_bus_out  = clk_bus_in;
assign lvds_out     = lvds_in;
assign lvds_bus_out = lvds_bus_in;

endmodule
