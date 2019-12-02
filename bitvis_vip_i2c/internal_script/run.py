#========================================================================================================================
# Copyright (c) 2018 by Bitvis AS.  All rights reserved.
# You should have received a copy of the license file containing the MIT License (see LICENSE.TXT), if not,
# contact Bitvis AS <support@bitvis.no>.
#
# UVVM AND ANY PART THEREOF ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH UVVM OR THE USE OR
# OTHER DEALINGS IN UVVM.
#========================================================================================================================

from os.path import join, dirname
from itertools import product
import os, sys, subprocess

sys.path.append("../../release/regression_test")
from testbench import Testbench


# Counters
num_tests_run = 0
num_failing_tests = 0


#=============================================================================================
# User edit starts here: define tests and run
#=============================================================================================

# Create testbench configuration with TB generics
def create_config(modes, data_widths, data_array_widths):
  config = []
  for mode, data_width, data_array_width in product(modes, data_widths, data_array_widths):
    config.append(str(mode) + ' ' + str(data_width) + ' ' + str(data_array_width))

  return config


def main(argv):
  global num_failing_tests
  tests = []

  tb = Testbench()
  tb.set_library("bitvis_vip_i2c")
  tb.check_arguments(argv)

  # Compile VIP, dependencies, DUTs, TBs etc
  tb.compile()


  # Define tests
  tests = [ "master_to_slave_VVC-to-VVC_7_bit_addressing",
            "slave_to_master_VVC-to-VVC_7_bit_addressing",
            "master_to_slave_VVC-to-VVC_10_bit_addressing",
            "slave_to_master_VVC-to-VVC_10_bit_addressing",
            "single-byte_communication_with_master_dut",
            "single-byte_communication_with_single_slave_dut",
            "single-byte_communication_with_multiple_slave_duts",
            "multi-byte_transmit_to_i2c_master_dut",
            "multi-byte_receive_from_i2c_master_dut",
            "multi-byte_transmit_to_i2c_slave_dut",
            "multi-byte_receive_from_i2c_slave_dut",
            "multi-byte_receive_from_i2c_slave_VVC-to-VVC",
            "multi-byte_transaction_with_i2c_master_dut_with_repeated_start_conditions",
            "single-byte_communication_with_multiple_slave_duts_without_stop_condition_in_between",
            "multi-byte_transmit_to_i2c_master_dut_10_bit_addressing",
            "multi-byte_receive_from_i2c_master_dut_10_bit_addressing",
            "receive_and_fetch_result",
            "multi-byte-send-and-receive-with-restart",
            "master-slave-vvc-quick-command",
            "master_quick_cmd_I2C_7bit_dut_test"]
  tb.add_tests(tests)

  # Setup testbench and run
  tb.set_tb_name("i2c_vvc_tb")
  tb.run_simulation()

  # Print simulation results
  tb.print_statistics()

  # Read number of failing tests for return value
  num_failing_tests = tb.get_num_failing_tests()




#=============================================================================================
# User edit ends here
#=============================================================================================
if __name__ == "__main__":
  main(sys.argv)

  # Return number of failing tests to caller
  sys.exit(num_failing_tests)