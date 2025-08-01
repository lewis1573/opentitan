// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// basic error test vseq
// During the channels are operating (patterns are not fully generated),
// this vseq can randomly disable channels that causes error patterns which
// must be detected and dropped in scoreboard and agent_monitor
class pattgen_error_vseq extends pattgen_base_vseq;
  `uvm_object_utils(pattgen_error_vseq)

  function new(string name="");
    super.new(name);
    error_injected_enb = 1'b1;
  endfunction

  virtual task pre_start();
    super.pre_start();
    // in order to inject error, the generated patterns should be long enough because
    // completed interrupts can be triggered before enable bit is unset in the last bit
    // which indicates a correct correct patterns
    cfg.seq_cfg.pattgen_min_prediv = 10;
    cfg.seq_cfg.pattgen_max_prediv = 20;
    cfg.seq_cfg.pattgen_min_len    = 5;
    cfg.seq_cfg.pattgen_min_reps   = 5;
  endtask : pre_start

endclass : pattgen_error_vseq
