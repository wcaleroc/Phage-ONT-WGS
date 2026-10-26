# Validation plan for `phage-ont-wgs`

## Gate 0 — source audit (required before implementation changes)

- [ ] Snapshot current branch and record commit SHA; do not modify `main`.
- [ ] Inventory every tracked file, including hidden files, and inspect current README, `run_all.sh`, scripts, configs, environments and SLURM templates.
- [ ] Search scripts for absolute home/scratch paths, account names, tokens, credentials, sample identifiers and data paths.
- [ ] Match each described stage to a real script, actual command, output, log and exit code.
- [ ] Label every tool as executed/verified, partially evaluated, installed only, or not run.

## Gate 1 — software and configuration

- [ ] Export environment specifications from the actual working Conda environment(s).
- [ ] Capture `command -v` and version output for each dependency from the job environment, not only the login node.
- [ ] Record database/model versions and update dates.
- [ ] Validate configuration keys and required input paths before starting compute-heavy work.
- [ ] Fail early with a useful message if a dependency, database, input file or required GPU is missing.

## Gate 2 — unit/smoke checks

- [ ] `bash -n` all shell scripts.
- [ ] Run `shellcheck` if available; document any intentional exceptions.
- [ ] Test missing arguments, nonexistent inputs, empty inputs, invalid stage names and absent databases.
- [ ] Confirm every stage returns a nonzero status on failure and `run_all.sh` stops instead of continuing with invalid outputs.
- [ ] Confirm logs include timestamps, command line, tool versions, job ID where available, and final exit status.
- [ ] Use synthetic or openly distributable tiny fixtures only; never use private sequencing data in repository tests.

## Gate 3 — HPC / SLURM validation

- [ ] Confirm partition, account, wall time, CPU, memory, GPU type and GPU count against current CEDIA policy.
- [ ] Confirm Dorado GPU execution only if basecalling is part of the workflow; test GPU visibility inside the allocated job.
- [ ] Verify environment activation and executable paths inside non-interactive SLURM jobs.
- [ ] Confirm output/log directories are created and jobs fail clearly if scratch or database paths are unavailable.
- [ ] Test a single sample/stage before arrays or full batches.

## Gate 4 — scientific consistency

- [ ] Confirm input/output counts at each stage and preserve assembly graphs/statistics.
- [ ] Confirm read mapping references the intended assembly and report coverage breadth and depth, not only mean depth.
- [ ] If a polishing stage exists, compare pre/post sequences, record the exact tool and show that it was actually run.
- [ ] If orientation/terminal normalization exists, document its rules and verify sequence identity/content before and after.
- [ ] Verify the GenBank used for annotation/maps corresponds to the exact FASTA sequence and orientation.
- [ ] Inspect repeated contigs, supplementary alignments and graph links before calling separate phage genomes.
- [ ] Never claim completeness or lytic lifestyle from coverage or annotation alone.

## Gate 5 — release readiness

- [ ] README and workflow diagram match the actual orchestration.
- [ ] Changelog separates planned changes from implemented changes.
- [ ] `CITATION.cff`, LICENSE and third-party database/tool citations are correct.
- [ ] `.gitignore` and a staged-diff audit exclude POD5, FASTQ, BAM/SAM, assemblies, sample genomes, logs containing private paths, secrets and sample-specific outputs.
- [ ] Run `git diff --check`, shell syntax tests and a clean-clone smoke test.
- [ ] Review branch diff; do not push or tag until owner approval.
