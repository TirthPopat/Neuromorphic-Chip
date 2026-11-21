set_io_pin_constraint -pin_names {clk rst_n tick reset_mode} -region top:*
set_io_pin_constraint -pin_names {ready_cores[0] ready_cores[1] ready_cores[2] ready_cores[3]} -region top:*
set_io_pin_constraint -pin_names {host_wr_en} -region bottom:*
set_io_pin_constraint -pin_names {threshold[0] threshold[1] threshold[2] threshold[3] threshold[4] threshold[5] threshold[6] threshold[7] threshold[8] threshold[9]} -region left:*
set_io_pin_constraint -pin_names {threshold[10] threshold[11] threshold[12] threshold[13] threshold[14] threshold[15] threshold[16] threshold[17] threshold[18] threshold[19]} -region bottom:*
set_io_pin_constraint -pin_names {leak_rate[0] leak_rate[1] leak_rate[2] leak_rate[3] leak_rate[4] leak_rate[5] leak_rate[6] leak_rate[7] leak_rate[8] leak_rate[9]} -region right:*
set_io_pin_constraint -pin_names {leak_rate[10] leak_rate[11] leak_rate[12] leak_rate[13] leak_rate[14] leak_rate[15] leak_rate[16] leak_rate[17] leak_rate[18] leak_rate[19]} -region right:*
