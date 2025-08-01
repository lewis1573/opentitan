// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
module tb;
  // dep packages
  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import rom_ctrl_env_pkg::*;
  import rom_ctrl_test_pkg::*;
  import rom_ctrl_bkdr_util_pkg::rom_ctrl_bkdr_util;

  // macro includes
  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  wire                        clk, rst_n;
  bit                         digest_cal_done;
  kmac_pkg::app_rsp_t         kmac_data_in;
  kmac_pkg::app_req_t         kmac_data_out;
  rom_ctrl_pkg::pwrmgr_data_t pwrmgr_data;
  rom_ctrl_pkg::keymgr_data_t keymgr_data;
  logic kmac_done_occured;

  // interfaces
  clk_rst_if clk_rst_if(.clk(clk), .rst_n(rst_n));
  clk_rst_if rom_clk_rst_if(.clk(), .rst_n()); // dummy clk_rst_vif for second RAL
  tl_if tl_rom_if(.clk(clk), .rst_n(rst_n));
  tl_if tl_if(.clk(clk), .rst_n(rst_n));
  kmac_app_intf kmac_app_if(.clk(clk), .rst_n(rst_n));

  `DV_ALERT_IF_CONNECT()

  assign kmac_app_if.kmac_data_req = kmac_data_out;
  assign kmac_data_in              = kmac_app_if.kmac_data_rsp;


  // dut
  rom_ctrl #(
    .RndCnstScrNonce      (RND_CNST_SCR_NONCE),
    .RndCnstScrKey        (RND_CNST_SCR_KEY),
    // ROM size in bytes
    .MemSizeRom           (ROM_SIZE_BYTES)
   ) dut (
    .clk_i                (clk),
    .rst_ni               (rst_n),

    .rom_cfg_i            (prim_rom_pkg::rom_cfg_t'('0)),

    .rom_tl_i             (tl_rom_if.h2d),
    .rom_tl_o             (tl_rom_if.d2h),

    .regs_tl_i            (tl_if.h2d),
    .regs_tl_o            (tl_if.d2h),

    .alert_rx_i           (alert_rx),
    .alert_tx_o           (alert_tx),

    .pwrmgr_data_o        (pwrmgr_data),
    .keymgr_data_o        (keymgr_data),

    .kmac_data_i          (kmac_data_in),
    .kmac_data_o          (kmac_data_out)
  );

  // Bind rom_ctrl_if into the rom_ctrl module
  bind dut rom_ctrl_if rom_ctrl_if ();

  // Bind a rom_ctrl_fsm_if into the fsm module (allowing DV to get its internal values and
  // parameters)
  bind dut.gen_fsm_scramble_enabled.u_checker_fsm rom_ctrl_fsm_if u_fsm_if ();

  // Bind a rom_ctrl_compare_if into the compare module (allowing DV to easily get hold of internal
  // values and parameters)
  bind dut.gen_fsm_scramble_enabled.u_checker_fsm.u_compare rom_ctrl_compare_if u_compare_if ();

  // Instantiate the memory backdoor util instance.
  `define ROM_CTRL_MEM_HIER \
    tb.dut.gen_rom_scramble_enabled.u_rom.u_rom.u_prim_rom.mem

  initial begin
    rom_ctrl_bkdr_util m_rom_ctrl_bkdr_util;
    m_rom_ctrl_bkdr_util = new(.name  ("rom_ctrl_bkdr_util"),
                               .path  (`DV_STRINGIFY(`ROM_CTRL_MEM_HIER)),
                               .depth ($size(`ROM_CTRL_MEM_HIER)),
                               .n_bits($bits(`ROM_CTRL_MEM_HIER)),
                               .err_detection_scheme(mem_bkdr_util_pkg::EccInv_39_32),
                               // Encryption configuration will be provided dynamically.
                               .key('0), .nonce('0)  // Not used.
                              );

    // drive clk and rst_n from clk_if
    clk_rst_if.set_active();
    rom_clk_rst_if.set_active();
    uvm_config_db#(virtual clk_rst_if)::set(null, "*.env", "clk_rst_vif", clk_rst_if);
    uvm_config_db#(virtual clk_rst_if)::set(null,
        "*.env", "clk_rst_vif_rom_ctrl_prim_reg_block", rom_clk_rst_if);
    uvm_config_db#(virtual tl_if)::set(null,
        "*.env.m_tl_agent_rom_ctrl_prim_reg_block*", "vif", tl_rom_if);
    uvm_config_db#(virtual tl_if)::set(null,
        "*.env.m_tl_agent_rom_ctrl_regs_reg_block*", "vif", tl_if);
    uvm_config_db#(rom_ctrl_bkdr_util)::set(null, "*.env", "rom_ctrl_bkdr_util",
        m_rom_ctrl_bkdr_util);
    uvm_config_db#(virtual kmac_app_intf)::set(null, "*.env.m_kmac_agent*", "vif", kmac_app_if);
    uvm_config_db#(rom_ctrl_vif)::set(null, "*.env", "rom_ctrl_vif", dut.rom_ctrl_if);
    uvm_config_db#(virtual rom_ctrl_fsm_if)::set(
        null, "*.env", "rom_ctrl_fsm_vif",
        dut.gen_fsm_scramble_enabled.u_checker_fsm.u_fsm_if);
    uvm_config_db#(virtual rom_ctrl_compare_if)::set(
        null, "*.env", "rom_ctrl_compare_vif",
        dut.gen_fsm_scramble_enabled.u_checker_fsm.u_compare.u_compare_if);

    $timeformat(-12, 0, " ps", 12);
    run_test();
  end
  // Only get one KMAC response
  `ASSERT(JustOneKmacResponse_A, kmac_data_in.done |=> always !kmac_data_in.done, clk, rst_n)
  // Once we signal done to pwrmgr, the done signal stays high and the good signal stays stable.
  `ASSERT(PwrmgrDoneOneWay_A, $rose(pwrmgr_data.done == prim_mubi_pkg::MuBi4True) |=>
          always $stable(pwrmgr_data), clk, rst_n)
  // Don't send any KMAC requests once we've had the response
  `ASSERT(KmacNotOutAfterIn_A, kmac_data_in.done |=> always !kmac_data_out.valid, clk, rst_n)
  always_comb begin
    if (!rst_n) kmac_done_occured = 0;
    else if (kmac_data_in.done) kmac_done_occured = 1;
  end
  // We see a response from KMAC before we assert that we're done to pwrmgr
  `ASSERT(KmacResponseBeforePwmgrDone_A,
          pwrmgr_data.done != prim_mubi_pkg::MuBi4False |-> kmac_done_occured, clk, rst_n)
  `undef ROM_CTRL_MEM_HIER

endmodule
