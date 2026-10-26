# Workflow and evidence requirements

This document is intentionally a workflow contract until the current implementation and CEDIA logs have been audited. It does not assign unverified commands to a particular stage.

## Provenance chain

For every sample, retain a private run manifest linking input file checksum and type to each stage's output checksum, tool version, parameters, command log, exit code and timestamps. The public repository should contain only the schema and synthetic examples, not private sample manifests.

## Stages to reconcile with the implementation

1. POD5 intake and basecalling (Dorado, only if run by this repository).
2. Demultiplexing and barcode/sample organization.
3. FASTQ integrity checks and read filtering.
4. Flye assembly and preservation of assembly FASTA, graph and statistics.
5. Minimap2 mapping and SAMtools-based mapping/coverage summaries.
6. Any actual polishing stage, including explicit before/after comparison.
7. Any actual sequence orientation or terminal-resolution stage.
8. Pharokka and the configured gene predictor / functional databases.
9. CheckV, Phold and reference comparison, only where the execution logs prove they were run.
10. Candidate review, extraction, annotation consistency and optional visualizations/comparisons.

## Scientific guardrails

- A higher coverage or longer contig is not automatically the correct genome.
- Supplementary alignments can arise from repeats, structural complexity or mapper behavior; they do not automatically represent independent genomes.
- Assembly graph edges and repeated sequences require contextual review.
- A circular assembly representation does not by itself prove physical circularity.
- CheckV estimates quality/completeness within its model and database limits.
- Missing annotated integrases/repressors does not prove a strictly lytic lifestyle.
