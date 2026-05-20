iverilog -o sim.vvp stopwatch/stopwatch_tb.v
vvp sim.vvp
gtkwave stopwatch_tb.vcd