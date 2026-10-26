# Changelog

All notable changes to this project will be documented here. This draft describes the **proposed** update; it is not a claim that changes have already been merged into `main`.

## [Unreleased] — reproducibility and audit update

### Planned
- Audit the current `main` branch before changing implementation.
- Document the observed workflow from POD5/basecalling through FASTQ organization, assembly, QC, mapping, any verified polishing/orientation, annotation and comparative characterization.
- Separate verified execution from installed/tested/pending tools.
- Add a sanitized example configuration and a software/database version manifest.
- Add consistent logging, input validation, dependency checks, exit-code handling and per-stage execution.
- Review SLURM templates for generic CEDIA HPC configuration, without personal paths, account names, credentials or guessed partitions.
- Add smoke tests and a documented validation checklist.
- Ensure large/private sequencing data and sample-specific outputs are excluded from Git.

### Not claimed yet
- No new release has been pushed.
- No scripts have been confirmed against the original CEDIA logs in this conversation.
- No software version or resource request is marked verified without source evidence.
- No sample-specific results are included in this update package.
