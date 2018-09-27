--========================================================================================================================
-- This VVC was generated with Bitvis VVC Generator
--========================================================================================================================


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library uvvm_vvc_framework;
use uvvm_vvc_framework.ti_vvc_framework_support_pkg.all;

library bitvis_vip_hvvc_to_vvc;

use work.ethernet_bfm_pkg.all;
use work.vvc_methods_pkg.all;
use work.vvc_cmd_pkg.all;
use work.td_target_support_pkg.all;
use work.td_vvc_entity_support_pkg.all;
use work.td_cmd_queue_pkg.all;
use work.td_result_queue_pkg.all;

--========================================================================================================================
entity ethernet_transmit_vvc is
  generic(
    GC_INSTANCE_IDX                          : natural;
    GC_CHANNEL                               : t_channel;
    GC_INTERFACE                             : t_interface;
    GC_SUB_VVC_INSTANCE_IDX                  : natural;
    GC_DUT_IF_FIELD_CONFIG                   : t_dut_if_field_config_channel_array;
    GC_ETHERNET_BFM_CONFIG                   : t_ethernet_bfm_config := C_ETHERNET_BFM_CONFIG_DEFAULT;
    GC_CMD_QUEUE_COUNT_MAX                   : natural               := 1000;
    GC_CMD_QUEUE_COUNT_THRESHOLD             : natural               := 950;
    GC_CMD_QUEUE_COUNT_THRESHOLD_SEVERITY    : t_alert_level         := WARNING;
    GC_RESULT_QUEUE_COUNT_MAX                : natural               := 1000;
    GC_RESULT_QUEUE_COUNT_THRESHOLD          : natural               := 950;
    GC_RESULT_QUEUE_COUNT_THRESHOLD_SEVERITY : t_alert_level         := WARNING
  );
end entity ethernet_transmit_vvc;

--========================================================================================================================
--========================================================================================================================
architecture behave of ethernet_transmit_vvc is

  constant C_SCOPE      : string        := C_VVC_NAME & "," & to_string(GC_INSTANCE_IDX);
  constant C_VVC_LABELS : t_vvc_labels  := assign_vvc_labels(C_SCOPE, C_VVC_NAME, GC_INSTANCE_IDX, GC_CHANNEL);

  signal executor_is_busy       : boolean := false;
  signal queue_is_increasing    : boolean := false;
  signal last_cmd_idx_executed  : natural := 0;
  signal terminate_current_cmd  : t_flag_record;
  signal hvvc_to_vvc            : t_hvvc_to_vvc(data_bytes(0 to C_MAX_PACKET_LENGTH-1));
  signal vvc_to_hvvc            : t_vvc_to_hvvc(data_bytes(0 to C_MAX_PACKET_LENGTH-1));

  -- Instantiation of the element dedicated executor
  shared variable command_queue : work.td_cmd_queue_pkg.t_generic_queue;
  shared variable result_queue  : work.td_result_queue_pkg.t_generic_queue;

  alias vvc_config : t_vvc_config is shared_ethernet_vvc_config(GC_CHANNEL, GC_INSTANCE_IDX);
  alias vvc_status : t_vvc_status is shared_ethernet_vvc_status(GC_CHANNEL, GC_INSTANCE_IDX);
  alias transaction_info : t_transaction_info is shared_ethernet_transaction_info(GC_CHANNEL, GC_INSTANCE_IDX);

begin

--========================================================================================================================
-- SUB VVC
--========================================================================================================================
  i_td_sub_vvc_engine : entity bitvis_vip_hvvc_to_vvc.hvvc_to_vvc
    generic map(
      GC_INTERFACE           => GC_INTERFACE,
      GC_INSTANCE_IDX        => GC_SUB_VVC_INSTANCE_IDX,
      GC_CHANNEL             => GC_CHANNEL,
      GC_DUT_IF_FIELD_CONFIG => GC_DUT_IF_FIELD_CONFIG
    )
    port map(
      hvvc_to_vvc => hvvc_to_vvc,
      vvc_to_hvvc => vvc_to_hvvc
    );


--========================================================================================================================
-- Constructor
-- - Set up the defaults and show constructor if enabled
--========================================================================================================================
  vvc_constructor(C_SCOPE, GC_INSTANCE_IDX, vvc_config, command_queue, result_queue, GC_ETHERNET_BFM_CONFIG,
                  GC_CMD_QUEUE_COUNT_MAX, GC_CMD_QUEUE_COUNT_THRESHOLD, GC_CMD_QUEUE_COUNT_THRESHOLD_SEVERITY,
                  GC_RESULT_QUEUE_COUNT_MAX, GC_RESULT_QUEUE_COUNT_THRESHOLD, GC_RESULT_QUEUE_COUNT_THRESHOLD_SEVERITY);
--========================================================================================================================


--========================================================================================================================
-- Command interpreter
-- - Interpret, decode and acknowledge commands from the central sequencer
--========================================================================================================================
  cmd_interpreter : process
     variable v_cmd_has_been_acked : boolean; -- Indicates if acknowledge_cmd() has been called for the current shared_vvc_cmd
     variable v_local_vvc_cmd      : t_vvc_cmd_record := C_VVC_CMD_DEFAULT;
  begin

    -- 0. Initialize the process prior to first command
    initialize_interpreter(terminate_current_cmd, global_awaiting_completion);
    -- initialise shared_vvc_last_received_cmd_idx for channel and instance
    shared_vvc_last_received_cmd_idx(GC_CHANNEL, GC_INSTANCE_IDX) := 0;

    -- Then for every single command from the sequencer
    loop  -- basically as long as new commands are received

      -- 1. wait until command targeted at this VVC. Must match VVC name, instance and channel (if applicable)
      --    releases global semaphore
      -------------------------------------------------------------------------
      await_cmd_from_sequencer(C_VVC_LABELS, vvc_config, THIS_VVCT, VVC_BROADCAST, global_vvc_busy, global_vvc_ack, shared_vvc_cmd, v_local_vvc_cmd);
      v_cmd_has_been_acked := false; -- Clear flag
      -- update shared_vvc_last_received_cmd_idx with received command index
      shared_vvc_last_received_cmd_idx(GC_CHANNEL, GC_INSTANCE_IDX) := v_local_vvc_cmd.cmd_idx;

      -- 2a. Put command on the executor if intended for the executor
      -------------------------------------------------------------------------
      if v_local_vvc_cmd.command_type = QUEUED then
        put_command_on_queue(v_local_vvc_cmd, command_queue, vvc_status, queue_is_increasing);

      -- 2b. Otherwise command is intended for immediate response
      -------------------------------------------------------------------------
      elsif v_local_vvc_cmd.command_type = IMMEDIATE then
        case v_local_vvc_cmd.operation is

          when AWAIT_COMPLETION =>
            -- Await completion of all commands in the cmd_executor executor
            interpreter_await_completion(v_local_vvc_cmd, command_queue, vvc_config, executor_is_busy, C_VVC_LABELS, last_cmd_idx_executed);

          when AWAIT_ANY_COMPLETION =>
            if not v_local_vvc_cmd.gen_boolean then
              -- Called with lastness = NOT_LAST: Acknowledge immediately to let the sequencer continue
              acknowledge_cmd(global_vvc_ack,v_local_vvc_cmd.cmd_idx);
              v_cmd_has_been_acked := true;
            end if;
            interpreter_await_any_completion(v_local_vvc_cmd, command_queue, vvc_config, executor_is_busy, C_VVC_LABELS, last_cmd_idx_executed, global_awaiting_completion);

          when DISABLE_LOG_MSG =>
            disable_log_msg(v_local_vvc_cmd.msg_id, vvc_config.msg_id_panel, to_string(v_local_vvc_cmd.msg) & format_command_idx(v_local_vvc_cmd), C_SCOPE, v_local_vvc_cmd.quietness);

          when ENABLE_LOG_MSG =>
            enable_log_msg(v_local_vvc_cmd.msg_id, vvc_config.msg_id_panel, to_string(v_local_vvc_cmd.msg) & format_command_idx(v_local_vvc_cmd), C_SCOPE, v_local_vvc_cmd.quietness);

          when FLUSH_COMMAND_QUEUE =>
            interpreter_flush_command_queue(v_local_vvc_cmd, command_queue, vvc_config, vvc_status, C_VVC_LABELS);

          when TERMINATE_CURRENT_COMMAND =>
            interpreter_terminate_current_command(v_local_vvc_cmd, vvc_config, C_VVC_LABELS, terminate_current_cmd);

          -- when FETCH_RESULT =>
            -- work.td_vvc_entity_support_pkg.interpreter_fetch_result(result_queue, v_local_vvc_cmd, vvc_config, C_VVC_LABELS, last_cmd_idx_executed, shared_vvc_response);

          when others =>
            tb_error("Unsupported command received for IMMEDIATE execution: '" & to_string(v_local_vvc_cmd.operation) & "'", C_SCOPE);

        end case;

      else
        tb_error("command_type is not IMMEDIATE or QUEUED", C_SCOPE);
      end if;

      -- 3. Acknowledge command after runing or queuing the command
      -------------------------------------------------------------------------
      if not v_cmd_has_been_acked then
        acknowledge_cmd(global_vvc_ack,v_local_vvc_cmd.cmd_idx);
      end if;

    end loop;
  end process;
--========================================================================================================================



--========================================================================================================================
-- Command executor
-- - Fetch and execute the commands
--========================================================================================================================
  cmd_executor : process
    variable v_cmd                                   : t_vvc_cmd_record;
    variable v_timestamp_start_of_current_bfm_access : time := 0 ns;
    variable v_timestamp_start_of_last_bfm_access    : time := 0 ns;
    variable v_timestamp_end_of_last_bfm_access      : time := 0 ns;
    variable v_command_is_bfm_access                 : boolean := false;
    variable v_prev_command_was_bfm_access           : boolean := false;
    variable v_ethernet_packet_raw                   : t_byte_array(0 to C_MAX_PACKET_LENGTH-1);
    variable v_payload_length                        : std_logic_vector(15 downto 0);
    variable v_crc_32                                : std_logic_vector(31 downto 0);
    variable v_cmd_idx                               : natural;
  begin

    -- Default values
    hvvc_to_vvc.dut_if_field_idx          <= 0;
    hvvc_to_vvc.current_byte_idx_in_field <= 0;

    -- 0. Initialize the process prior to first command
    -------------------------------------------------------------------------
    initialize_executor(terminate_current_cmd);
    loop

      -- 1. Set defaults, fetch command and log
      -------------------------------------------------------------------------
      fetch_command_and_prepare_executor(v_cmd, command_queue, vvc_config, vvc_status, queue_is_increasing, executor_is_busy, C_VVC_LABELS);

      -- Reset the transaction info for waveview
      transaction_info := C_TRANSACTION_INFO_DEFAULT;
      transaction_info.operation := v_cmd.operation;
      transaction_info.msg := pad_string(to_string(v_cmd.msg), ' ', transaction_info.msg'length);

      -- Check if command is a BFM access
      v_prev_command_was_bfm_access := v_command_is_bfm_access; -- save for inter_bfm_delay

      if v_cmd.operation = SEND then  -- Replace this line with actual check
        v_command_is_bfm_access := true;
      else
        v_command_is_bfm_access := false;
      end if;

      -- Insert delay if needed
      insert_inter_bfm_delay_if_requested(vvc_config                         => vvc_config,
                                          command_is_bfm_access              => v_prev_command_was_bfm_access,
                                          timestamp_start_of_last_bfm_access => v_timestamp_start_of_last_bfm_access,
                                          timestamp_end_of_last_bfm_access   => v_timestamp_end_of_last_bfm_access,
                                          scope                              => C_SCOPE);

      if v_command_is_bfm_access then
        v_timestamp_start_of_current_bfm_access := now;
      end if;

      -- 2. Execute the fetched command
      -------------------------------------------------------------------------
      case v_cmd.operation is  -- Only operations in the dedicated record are relevant

        -- VVC dedicated operations
        --===================================

        when SEND =>

          -- Preamble and SFD
          for i in 0 to 6 loop
            v_ethernet_packet_raw(i) := C_PREAMBLE(55-(i*8) downto 55-(i*8)-7);
          end loop;
          v_ethernet_packet_raw(7) := C_SFD;

          -- MAC destination
          v_ethernet_packet_raw( 8 to 13) := v_cmd.mac_destination;
          v_ethernet_packet_raw(14 to 19) := v_cmd.mac_source;

          -- Length
          v_payload_length := std_logic_vector(to_unsigned(v_cmd.payload_length, 16));
          v_ethernet_packet_raw(20) := v_payload_length(15 downto 8);
          v_ethernet_packet_raw(21) := v_payload_length( 7 downto 0);

          -- Payload
          v_ethernet_packet_raw(22 to 22+v_cmd.payload_length-1) := v_cmd.payload(0 to v_cmd.payload_length-1);

          -- FCS
          v_crc_32 := generate_crc_32_complete(v_ethernet_packet_raw(0 to 22+v_cmd.payload_length-1));
          v_crc_32 := not(v_crc_32);
          v_ethernet_packet_raw(22+v_cmd.payload_length)   := v_crc_32(31 downto 24);
          v_ethernet_packet_raw(22+v_cmd.payload_length+1) := v_crc_32(23 downto 16);
          v_ethernet_packet_raw(22+v_cmd.payload_length+2) := v_crc_32(15 downto  8);
          v_ethernet_packet_raw(22+v_cmd.payload_length+3) := v_crc_32( 7 downto  0);

          -- Add info to the transaction_for_waveview_struct
          transaction_info.ethernet_frame.mac_destination := v_cmd.mac_destination;
          transaction_info.ethernet_frame.mac_source      := v_cmd.mac_source;
          transaction_info.ethernet_frame.length          := (v_payload_length(15 downto 8), v_payload_length(7 downto 0));
          transaction_info.ethernet_frame.payload         := v_cmd.payload;
          transaction_info.ethernet_frame.fcs             := (v_crc_32(31 downto 24), v_crc_32(23 downto 16), v_crc_32(15 downto  8), v_crc_32( 7 downto  0));

          -- Send to sub-VVC
          hvvc_to_vvc.operation                                  <= SEND;
          hvvc_to_vvc.num_data_bytes                             <= 22+v_cmd.payload_length+4;
          hvvc_to_vvc.data_bytes(0 to 22+v_cmd.payload_length+3) <= v_ethernet_packet_raw(0 to 22+v_cmd.payload_length+3);
          hvvc_to_vvc.trigger <= '1';
          wait for 0 ns;
          hvvc_to_vvc.trigger <= '0';
          wait until vvc_to_hvvc.trigger = '1';



        -- UVVM common operations
        --===================================
        when INSERT_DELAY =>
          log(ID_INSERTED_DELAY, "Running: " & to_string(v_cmd.proc_call) & " " & format_command_idx(v_cmd), C_SCOPE, vvc_config.msg_id_panel);
          if v_cmd.gen_integer_array(0) = -1 then
            -- Delay specified using time
            wait until terminate_current_cmd.is_active = '1' for v_cmd.delay;
          else
            -- Delay specified using integer
            --wait until terminate_current_cmd.is_active = '1' for v_cmd.gen_integer_array(0) * vvc_config.bfm_config.clock_period;
          end if;

        when others =>
          tb_error("Unsupported local command received for execution: '" & to_string(v_cmd.operation) & "'", C_SCOPE);
      end case;

      if v_command_is_bfm_access then
        v_timestamp_end_of_last_bfm_access := now;
        v_timestamp_start_of_last_bfm_access := v_timestamp_start_of_current_bfm_access;
        if ((vvc_config.inter_bfm_delay.delay_type = TIME_START2START) and
           ((now - v_timestamp_start_of_current_bfm_access) > vvc_config.inter_bfm_delay.delay_in_time)) then
          alert(vvc_config.inter_bfm_delay.inter_bfm_delay_violation_severity, "BFM access exceeded specified start-to-start inter-bfm delay, " &
                to_string(vvc_config.inter_bfm_delay.delay_in_time) & ".", C_SCOPE);
        end if;
      end if;

      -- Reset terminate flag if any occurred
      if (terminate_current_cmd.is_active = '1') then
        log(ID_CMD_EXECUTOR, "Termination request received", C_SCOPE, vvc_config.msg_id_panel);
        uvvm_vvc_framework.ti_vvc_framework_support_pkg.reset_flag(terminate_current_cmd);
      end if;

      last_cmd_idx_executed <= v_cmd.cmd_idx;
      -- Reset the transaction info for waveview
      transaction_info   := C_TRANSACTION_INFO_DEFAULT;

    end loop;
  end process;
--========================================================================================================================



--========================================================================================================================
-- Command termination handler
-- - Handles the termination request record (sets and resets terminate flag on request)
--========================================================================================================================
  cmd_terminator : uvvm_vvc_framework.ti_vvc_framework_support_pkg.flag_handler(terminate_current_cmd);  -- flag: is_active, set, reset
--========================================================================================================================

end behave;


