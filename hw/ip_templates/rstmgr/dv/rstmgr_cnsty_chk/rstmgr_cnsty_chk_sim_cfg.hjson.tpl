// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
{
  // Name of the sim cfg - typically same as the name of the DUT.
  name: rstmgr_cnsty_chk

  // Top level dut name (sv module).
  dut: rstmgr_cnsty_chk

  // Top level testbench name (sv module).
  tb: tb

  // Simulator used to sign off this block
  tool: vcs

  // Fusesoc core file used for building the file list.
  fusesoc_core: ${instance_vlnv("lowrisc:dv:rstmgr_cnsty_chk_sim:0.1")}

  // Testplan hjson file.
  testplan: "{self_dir}/data/rstmgr_cnsty_chk_testplan.hjson"

  // Import additional common sim cfg files.
  import_cfgs: ["{proj_root}/hw/dv/tools/dvsim/common_sim_cfg.hjson"]


  // Specific exclusion files.
  vcs_cov_excl_files: ["{self_dir}/cov_manual_excl.el",
                       "{self_dir}/cov_unr_excl.el"]

  // Default iterations for all tests - each test entry can override this.
  reseed: 10

  // Enable cdc instrumentation.
  run_opts: ["+cdc_instrumentation_enabled=1"]

  // List of test specifications.
  tests: [
    {
      name: rstmgr_cnsty_chk_test
    }
  ]
  // List of regressions.
  regressions: [
    {
      name: smoke
      tests: ["rstmgr_cnsty_chk_test"]
    }
  ]
}
