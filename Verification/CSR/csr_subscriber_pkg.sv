package csr_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import csr_item_pkg::*;
    import shared_pkg::*;

    class csr_subscriber extends uvm_subscriber #(csr_item);

        `uvm_component_utils(csr_subscriber)

        csr_item sub_item;

        // ── Functional coverage model ────────────────────────────────────────
        // rst here is active-high "operating" (item drives rst dist {0:=5,1:=400}),
        // so the CSR is exercised while rst==1. Access/operation points are gated
        // by CsrAccess as well. Bins follow the item constraints so every bin is
        // reachable (constrained-out encodings become ignore_bins).
        covergroup cvr_grp();

            // Reset / operating split.
            rst_cg: coverpoint sub_item.rst
            {
                bins idle      = {0};
                bins operating = {1};
            }

            // CSR access enable.
            CsrAccess_cg: coverpoint sub_item.CsrAccess iff(sub_item.rst)
            {
                bins no_access = {0};
                bins access    = {1};
            }

            // CSR operation - only the six R/W ops occur under access
            // (ValidCsrOperation constraint), system is excluded.
            CsrOperation_cg: coverpoint sub_item.CsrOperation iff(sub_item.rst && sub_item.CsrAccess)
            {
                bins csrrw_op  = {csrrw};
                bins csrrs_op  = {csrrs};
                bins csrrc_op  = {csrrc};
                bins csrrwi_op = {csrrwi};
                bins csrrsi_op = {csrrsi};
                bins csrrci_op = {csrrci};
                ignore_bins not_under_access = {system}; // never reachable when CsrAccess
            }

            // CSR index - read-only registers are excluded under access
            // (WritableCsrSelection constraint).
            CsrIndex_cg: coverpoint sub_item.CsrIndex iff(sub_item.rst && sub_item.CsrAccess)
            {
                bins fflags_idx   = {fflags};
                bins frm_idx      = {frm};
                bins fcsr_idx     = {fcsr};
                bins mstatus_idx  = {mstatus};
                bins medeleg_idx  = {medeleg};
                bins mideleg_idx  = {mideleg};
                bins mie_idx      = {mie};
                bins mtvec_idx    = {mtvec};
                bins mscratch_idx = {mscratch};
                bins mepc_idx     = {mepc};
                bins mcause_idx   = {mcause};
                bins mbadaddr_idx = {mbadaddr};
                bins mcycle_idx   = {mcycle};
                bins mhartid_idx  = {mhartid};
                ignore_bins read_only = {misa, mvendorid, mip}; // excluded under access
            }

            // Trap cause stimulus (all thirteen encodings).
            Traps_cg: coverpoint sub_item.Traps iff(sub_item.rst)
            {
                bins no_trap                  = {NoTraps};
                bins instr_addr_misaligned    = {InstructionAddressMisalignedOrUserSoftwareInterrupt};
                bins instr_access_fault       = {InstructionAccessFaultOrSupervisorSoftwareInterrupt};
                bins illegal_instruction      = {IllegalInstructionOrHypervisorSoftwareInterrupt};
                bins breakpoint               = {BreakpointOrMachineSoftwareInterrupt};
                bins load_addr_misaligned     = {LoadAddressMisalignedOrUserSoftwareInterrupt};
                bins load_access_fault        = {LoadAddressFaultOrSupervisorTimerInterrupt};
                bins store_addr_misaligned    = {StoreAddressMisalignedOrHyperVisorTimerInterrupt};
                bins store_access_fault       = {StoreAddressFaultOrMachineTimerInterrupt};
                bins ecall_u                  = {EcallUOrUserExternalInterrupt};
                bins ecall_s                  = {EcallSOrSupervisorExternalInterrupt};
                bins ecall_h                  = {EcallHOrHypervisorExternalInterrupt};
                bins ecall_m                  = {EcallMOrMachineExternalInterrupt};
            }

            // Machine return.
            mret_cg: coverpoint sub_item.mret iff(sub_item.rst)
            {
                bins no_mret = {0};
                bins mret    = {1};
            }

            // Interrupt request lines.
            TimerInterrupt_cg: coverpoint sub_item.TimerInterrupt iff(sub_item.rst)
            {
                bins low  = {0};
                bins high = {1};
            }
            ExternalInterrupt_cg: coverpoint sub_item.ExternalInterrupt iff(sub_item.rst)
            {
                bins low  = {0};
                bins high = {1};
            }
            SoftwareInterrupt_cg: coverpoint sub_item.SoftwareInterrupt iff(sub_item.rst)
            {
                bins low  = {0};
                bins high = {1};
            }

            // Trap-taken output.
            TrapIsSet_cg: coverpoint sub_item.TrapIsSet iff(sub_item.rst)
            {
                bins clear = {0};
                bins set   = {1};
            }

            // Rounding mode output (driven by frm / fcsr writes).
            RoundingMode_cg: coverpoint sub_item.RoundingMode iff(sub_item.rst)
            {
                bins rne = {RNE};
                bins rtz = {RTZ};
                bins rdn = {RDN};
                bins rup = {RUP};
                bins rmm = {RMM};
                bins dyn = {DYN};
            }

            // ── Crosses ──────────────────────────────────────────────────────
            // Each writable CSR exercised with each R/W operation.
            CsrOp_x_CsrIndex_cx: cross CsrOperation_cg, CsrIndex_cg;

            // Trap cause vs machine-return. mret is forced low whenever a trap is
            // present (DirectedTraffic), so only NoTraps pairs with mret==1.
            Traps_x_mret_cx: cross Traps_cg, mret_cg
            {
                ignore_bins trap_with_mret = binsof(mret_cg.mret) && (!binsof(Traps_cg.no_trap));
            }

            // Interrupt lines vs the resulting trap-taken flag.
            Timer_x_Trap_cx:    cross TimerInterrupt_cg,    TrapIsSet_cg;
            External_x_Trap_cx: cross ExternalInterrupt_cg, TrapIsSet_cg;
            Software_x_Trap_cx: cross SoftwareInterrupt_cg, TrapIsSet_cg;

        endgroup:cvr_grp

        function new (string name = "csr_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:csr_subscriber

endpackage: csr_subscriber_pkg
