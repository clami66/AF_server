# Snakemake workflow: `AF_server`

[![Snakemake](https://img.shields.io/badge/snakemake-≥6.3.0-brightgreen.svg)](https://snakemake.github.io)
[![GitHub actions status](https://github.com/<owner>/<repo>/workflows/Tests/badge.svg?branch=main)](https://github.com/<owner>/<repo>/actions?query=branch%3Amain+workflow%3ATests)


A Snakemake workflow to serve AlphaFold queries through an email server


## Setup

1. Clone this repository
2. Edit the configuration file `config/config.yaml`
3. If on HPC, edit `config/envmodules.yaml` to load necessary modules through `module load`
4. Submitting queries must be explicitly allowed by editing the whitelist `config/whitelist` and adding allowed source email addresses
5. SLURM configuration is handled by the `slurm/` snakemake profile

## Usage

To invoke the pipeline, run:

```
# password to the inbox/outbox
export EMAIL_PASS=...
snakemake -j 8 --rerun-incomplete --cores 16 --profile slurm --use-conda --use-envmodules
```

The password to the email account used to serve the queries must be passed through the environmental variable `EMAIL_PASS`

The `--use-conda` flag allows to setup the environment for AlphaFold (tested on v2.2) defined at `workflow/envs/environment.yaml` the argument `
