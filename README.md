# phage-ont-wgs

**An Oxford Nanopore sequencing workflow for bacteriophage genome assembly, quality assessment, polishing, annotation, and reporting.**

## Overview

`phage-ont-wgs` is a collection of Bash scripts, configuration files, Conda environment definitions, and SLURM job scripts designed to support the bioinformatic analysis of bacteriophage genomes generated using Oxford Nanopore Technologies (ONT) sequencing.

The workflow is intended for execution in a high-performance computing (HPC) environment. It organizes the main stages of phage genome processing while keeping configuration, software environments, execution scripts, and documentation in separate directories.

The workflow may start from raw ONT signal data or basecalled reads, depending on the selected input type and configuration.

**Reproducibility note:** The presence of a script or software environment does not establish that a stage has completed successfully. Tool versions, database versions, execution logs, and validation results must be recorded for each actual run. End-to-end execution has not yet been established by the documentation update alone.

## Workflow overview

The repository organizes the analysis into the following stages:

1. **Basecalling** — Convert ONT signal data into sequence reads using Dorado when required.
2. **Demultiplexing** — Assign reads to samples using the configured demultiplexing procedure.
3. **Read quality control and filtering** — Assess and filter reads according to the implemented configuration.
4. **Genome assembly and quality assessment** — Assemble reads and evaluate the resulting viral genome candidates.
5. **Polishing** — Improve draft assembly consensus using the configured polishing procedure, including Medaka where specified.
6. **Terminal sequence assessment and orientation** — Assess assembly termini and orientation using the implemented alignment procedure.
7. **Annotation and screening** — Run the annotation and screening steps configured in the corresponding script.
8. **Reporting** — Collect available analysis outputs into a summary report.

The stages and their dependencies must be checked against the actual scripts, configuration, installed tools, and execution logs before interpreting any result as validated.

## Repository structure

```text
phage-ont-wgs/
├── config/
│   ├── config.yaml
│   ├── config.example.yaml
│   ├── samples.tsv
│   └── samples.example.tsv
├── docs/
│   ├── CONCORDANCIA.md
│   ├── adaptacion-desde-pipeline-bacteriano.md
│   ├── steps/
│   ├── troubleshooting.md
│   ├── validation.md
│   └── workflow.md
├── envs/
│   ├── phage-annot.yml
│   ├── phage-asm.yml
│   ├── phage-phold.yml
│   ├── phage-polish.yml
│   ├── phage-qc.yml
│   ├── phage-qual.yml
│   ├── phage-safe.yml
│   └── phage-tax.yml
├── metadata/
│   ├── run_manifest.template.tsv
│   └── software_versions.template.tsv
├── scripts/
│   ├── 00_preflight.sh
│   ├── 00_setup_envs.sh
│   ├── 01_basecall.sh
│   ├── 02_demux.sh
│   ├── 03_readqc_filter.sh
│   ├── 04_assemble_validate.sh
│   ├── 05_polish.sh
│   ├── 06_termini_orient.sh
│   ├── 07_annotate_screen.sh
│   ├── 08_report.sh
│   └── lib/
├── slurm/
│   ├── array.sbatch
│   ├── basecall.sbatch
│   ├── pipeline.sbatch
│   └── README.md
├── CHANGELOG.md
├── CITATION.cff
├── LICENSE
├── README.md
└── run_all.sh
```

The exact contents of configuration files and the set of stages executed depend on the selected pipeline setup.

## Software and dependencies

The repository contains environment definitions and scripts that reference bioinformatics tools used in different workflow stages. These include:

- **Dorado** — ONT basecalling and demultiplexing.
- **Filtlong** — Read filtering, where configured.
- **Flye** — Long-read genome assembly.
- **Minimap2** and **SAMtools** — Sequence alignment and alignment-file processing.
- **Medaka** — Consensus polishing, where configured.
- **CheckV** — Viral genome quality assessment.
- **Pharokka** — Phage genome annotation.
- **Phold** — Protein structure-informed phage annotation.
- **Mash** — Sequence-based comparison and taxonomic support, where configured.

This list describes tools referenced by the repository; it is not a guarantee that every tool is required or successfully installed for every run.

Software compatibility, database availability, model selection, GPU requirements, and tool versions must be checked in the target HPC environment. The environment files in `envs/` and the setup script in `scripts/` should be reviewed before installation or execution.

## Configuration

The main configuration files are:

- `config/config.yaml` — Workflow parameters and paths used by the current setup.
- `config/samples.tsv` — Sample manifest used by the current setup.
- `config/config.example.yaml` — Example configuration template.
- `config/samples.example.tsv` — Example sample manifest.

Review the configuration before running the workflow. Input paths, output directories, software locations, databases, thread counts, and stage-specific parameters must match the actual CEDIA environment.

Example files are templates and may require adaptation to the parser and options implemented by the current scripts.

## Running on an HPC system

The top-level launcher is `run_all.sh`. Before executing it, inspect the launcher and the individual stage scripts to determine the expected arguments, configuration requirements, and execution order.

The repository includes SLURM scripts for pipeline execution, basecalling, and array jobs. These are starting points, not universal resource specifications.

Before submitting jobs:

1. Verify the available CEDIA partitions and GPU resources.
2. Confirm CPU, memory, wall-time, and filesystem requirements.
3. Check that the required Conda environments, executables, models, and databases are available.
4. Confirm that input and output paths are valid and writable.
5. Run a small test dataset before processing the full dataset.
6. Preserve logs, exit codes, software versions, and database versions for every stage.

See `slurm/README.md` and `docs/troubleshooting.md` for additional guidance.

## Quality control and validation

Successful execution must be assessed using the actual output files, logs, and exit codes rather than installation status alone.

The validation process should distinguish between:

- **Verified** — Supported by execution evidence and appropriate output checks.
- **Partially verified** — Some checks passed, but evidence is incomplete.
- **Not run** — The stage has not been executed.
- **Unknown** — Available evidence is insufficient to determine the status.

See `docs/validation.md` for the validation framework and `docs/workflow.md` for the workflow overview.

Genome coverage, annotation results, or the presence of a circular assembly do not, on their own, establish genome completeness, a strictly lytic lifestyle, or a definitive genome topology. Biological conclusions should be supported by appropriate evidence.

## Reproducibility and metadata

The `metadata/` directory contains templates for recording:

- Run identifiers and relevant sample metadata.
- Software versions and execution details.
- Database versions or snapshots.
- Output locations and validation status.

Complete these records using information from actual executions. Do not infer versions, successful runs, or database states from environment definitions alone.

The templates are intended to support reproducible analysis and transparent reporting.

## Data management and security

Raw sequencing reads, private sample information, credentials, and large intermediate files should be stored in appropriate project storage rather than committed to the repository.

Before sharing the repository publicly:

- Review configuration files for personal or institutional paths.
- Check the Git history for sensitive files that may have been committed previously.
- Confirm that `.gitignore` covers raw reads, intermediate files, logs, databases, and private results.
- Use example configurations and sanitized metadata when sharing the workflow.
- Never commit passwords, tokens, private keys, or credentials.

A `.gitignore` file does not remove data that has already been committed to Git history.

## Contributing

Contributions that improve reproducibility, documentation, testing, portability, and validation are welcome.

A recommended contribution process is:

1. Create a separate branch for the proposed change.
2. Describe the purpose and scope of the change.
3. Test the modified script or documentation where possible.
4. Record any relevant validation evidence.
5. Submit a pull request for review.

Changes to production configuration, software environments, or workflow execution logic should be reviewed carefully before merging.

## Citation and license

Please consult `CITATION.cff` for repository citation metadata and `LICENSE` for the applicable license terms.

When publishing results generated with this workflow, report the relevant software versions, reference databases, parameters, and validation evidence.

## Project status

This repository provides an organized starting point for an ONT bacteriophage genome analysis workflow. Documentation and metadata templates support reproducibility, but complete end-to-end validation must be established using actual execution records from the target HPC environment.

Workflow stages should be described as validated only when supported by appropriate evidence.
