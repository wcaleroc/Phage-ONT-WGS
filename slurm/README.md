# SLURM templates — CEDIA HPC

Do not copy resource values from a generic example into production. Partition names, account directives, GPU syntax, memory limits, wall time, module setup and scratch policy must be confirmed against the current CEDIA documentation and the original working job scripts.

The existing `slurm/` scripts must be audited first. Keep the actual verified directives where possible; replace only personal paths/account identifiers with documented variables or site-specific placeholders.

Before release, verify:

- non-interactive Conda activation works in the batch shell;
- executable and database paths are available on compute nodes;
- log and output directories exist and are writable;
- CPU/memory/time requests reflect observed resource use;
- Dorado requests a GPU only when the basecalling stage needs it and the selected CEDIA partition supports it;
- job exit status propagates to the wrapper and failed stages cannot be marked complete.
