--================================================================================================================================
-- Copyright 2020 Bitvis
-- Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 and in the provided LICENSE.TXT.
--
-- Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
-- an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and limitations under the License.
--================================================================================================================================
-- Note : Any functionality not explicitly described in the documentation is subject to change at any time
----------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- Description   : See library quick reference (under 'doc') and README-file(s)
------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

package generic_sb_support_pkg is


  function sb_pad(
    constant pad_data   : std_logic_vector;
    constant pad_width  : positive := C_SB_SLV_WIDTH
  ) return std_logic_vector;


  type t_sb_config is record
    mismatch_alert_level      : t_alert_level;
    allow_lossy               : boolean;
    allow_out_of_order        : boolean;
    overdue_check_alert_level : t_alert_level;
    overdue_check_time_limit  : time;
    ignore_initial_garbage    : boolean;
    element_width             : positive;
  end record;

  type t_sb_config_array is array(integer range <>) of t_sb_config;

  constant C_SB_CONFIG_DEFAULT : t_sb_config := (mismatch_alert_level      => ERROR,
                                                 allow_lossy               => false,
                                                 allow_out_of_order        => false,
                                                 overdue_check_alert_level => ERROR,
                                                 overdue_check_time_limit  => 0 ns,
                                                 ignore_initial_garbage    => false,
                                                 element_width             => 8);

end package generic_sb_support_pkg;


package body generic_sb_support_pkg is


  function sb_pad(
    constant pad_data   : std_logic_vector;
    constant pad_width  : positive := C_SB_SLV_WIDTH
  ) return std_logic_vector is

    variable v_asc_slv : std_logic_vector(0 to pad_width-1) := (others => '0');
    variable v_des_slv : std_logic_vector(pad_width-1 downto 0) := (others => '0');
  begin
    check_value(pad_data'length <= pad_width, TB_WARNING, "check: pad_data width exceed pad_width");

    if pad_data'ascending then
      v_asc_slv(0 to pad_data'length-1) := pad_data;
      return v_asc_slv;
    else
      v_des_slv(pad_data'length-1 downto 0) := pad_data;
      return v_des_slv;
    end if;
  end function sb_pad;

end package body generic_sb_support_pkg;