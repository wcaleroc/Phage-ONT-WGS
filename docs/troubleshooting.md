# Troubleshooting record — items to confirm against original logs

This file records audit questions, not claims that every issue below occurred or was solved in the final production run.

## Dorado / GPU

- Capture Dorado version, model name and exact command.
- Check that the model is compatible with the installed Dorado release and the chemistry/basecaller configuration used for the data.
- Test GPU visibility from inside the SLURM allocation, not just on the login node.
- Record GPU model, driver/CUDA compatibility as applicable, SLURM GPU request and job log.
- Do not move to a cloud GPU command or assume a GPU partition was available unless the actual run record supports it.

## FASTQ and barcode organization

- Confirm whether FASTQ files are per-read, per-barcode, split across chunks, compressed, or concatenated.
- Check read counts, empty files, duplicate paths and filename conventions before assembly.
- Never merge barcodes or samples without an explicit documented reason.

## Assembly and contig interpretation

- Preserve Flye assembly graph and assembly statistics.
- Check whether mode/estimated genome size fit the dataset and whether reads came from one phage or a mixed population.
- Treat repeated contigs, circularity labels, graph links and supplementary alignments as evidence requiring review, not automatic proof of separate genomes or completeness.

## Missing or failed tools

- Separate a package installation test from a successful analysis run.
- Record exact stderr/stdout and exit code. Do not suppress errors or continue downstream when required output is missing.
- Confirm database paths and database versions inside the batch job environment.

## Polishing / orientation

- Identify the actual tool and command from the script/log before documenting it as used.
- If not executed, mark the step as absent or pending rather than adding a plausible command retrospectively.
- Compare input/output sequences and lengths and document any coordinate/orientation changes.
