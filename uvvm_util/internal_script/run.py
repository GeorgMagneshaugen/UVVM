#================================================================================================================================
# Copyright 2020 Bitvis
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 and in the provided LICENSE.TXT.
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.
#================================================================================================================================
# Note : Any functionality not explicitly described in the documentation is subject to change at any time
#--------------------------------------------------------------------------------------------------------------------------------

from os.path import join, dirname
from itertools import product
import os, sys, subprocess

sys.path.append("../../release/regression_test")
from testbench import Testbench


# Counters
num_tests_run = 0
num_failing_tests = 0

#=============================================================================================
#
# Define tests and run - user to edit this
#
#=============================================================================================

# Create testbench configuration with TB generics
def create_config(modes, data_widths, data_array_widths):
  config = []
  for mode, data_width, data_array_width in product(modes, data_widths, data_array_widths):
    config.append(str(mode) + ' ' + str(data_width) + ' ' + str(data_array_width))

  return config


def main(argv):
  global num_failing_tests

  tb = Testbench()
  tb.set_library("uvvm_util")
  tb.check_arguments(argv)

  # Compile VIP, dependencies, DUTs, TBs etc
  tb.compile()


  tests = [ "basic_log_alert",
            "enable_disable_log_msg",
            "check_value",
            "check_stable",
            "await_stable",
            "await_change",
            "await_value",
            "byte_and_slv_arrays",
            "random_functions",
            "check_value_in_range",
            "string_methods",
            "clock_generators",
            "normalise",
            "normalize_and_check",
            "log_text_block",
            "log_to_file",
            "log_header_formatting",
            "ignored_alerts",
            "hierarchical_alerts",
            "setting_output_file_name",
            "synchronization_methods",
            "watchdog_timer",
            "optional_alert_level"
            ]

  # Setup testbench and run
  tb.set_tb_name("methods_tb")
  tb.add_tests(tests)
  tb.set_cleanup(False)
  tb.add_expected_failing_testcase("setting_output_file_name")
  tb.run_simulation()


  # Print simulation results
  tb.print_statistics()

  # Read number of failing tests for return value
  num_failing_tests = tb.get_num_failing_tests()




if __name__ == "__main__":
  main(sys.argv)

  # Return number of failing tests to caller
  sys.exit(num_failing_tests)
