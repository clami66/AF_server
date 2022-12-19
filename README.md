# Snakemake workflow: `AF_server`

[![Snakemake](https://img.shields.io/badge/snakemake-≥6.3.0-brightgreen.svg)](https://snakemake.github.io)
[![GitHub actions status](https://github.com/<owner>/<repo>/workflows/Tests/badge.svg?branch=main)](https://github.com/<owner>/<repo>/actions?query=branch%3Amain+workflow%3ATests)


A Snakemake workflow to serve AlphaFold queries through an email server


## Setup

0. [Install Snakemake](https://snakemake.readthedocs.io/en/stable/getting_started/installation.html)
1. Clone this repository
2. Edit the configuration file `config/config.yaml` (see README inside the `config/` directory)
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

The server can be invoked automatically in a crontab job every few minutes.

The password to the email account used to serve the queries must be passed through the environmental variable `EMAIL_PASS`

The `--j` flag specifies the number of parallel snakemake instances (i.e. maximum numbers of target that can be modelled at the same time)

The `--use-conda` flag allows to setup the environment for AlphaFold (tested on v2.2) defined at `workflow/envs/environment.yaml`

The `--use-envmodules` flag allows to specify and load HPC modules (`module load ...`) in `config/envmodules.yaml`. This is especially useful on systems where AlphaFold or the alignment tools are available as environmental modules.

## Querying the server

When the server is setup and running, it is possible to query it by sending an email to the server inbox specified in `config/config.yaml`. The email should be in plain text and the sequences should be pasted in the body as follows (no attachments):

* `TARGET` field contains the name of the target
* `SEQUENCE` field: contains one (monomer) or more (multimer) fasta sequences (see examples below)
* `REPLY` field: the email address where results should be sent to. This does not have to be the same as the sender address
* `STOICHIOMETRY` field: specify how many times each chain (starting from A) should be repeated in the model

**Example: monomer**

```
TARGET=targetID
SEQUENCE=GHMSKPQTQGLAKDAWEIPRESLRLEVKLGQGCFGEVWMGTWNGTTRVAIKTLKPGTMSPEAFLQEAQVMKKLRHEKLVQLYAVVSEEPIYIVTEYMSKGSLLDFLKGEMGKYLRLPQLVDMAAQIASGMAYVERMNYVHRDLRAANILVGENLVCKVADFGLARLIEDNEYTARQGAKFPIKWTAPEAALYGRFTIKSDVWSFGILLTELTTKGRVPYPGMVNREVLDQVERGYRMPCPPECPESLHDLMCQCWRKDPEERPTFEYLQAFLEDYFTSTEPQYQPGENL
REPLY=user@mail.com
STOICHIOMETRY=A1
```

**Example: homodimer (A2 stoichiometry)**

```
TARGET=targetID_homodimer
SEQUENCE=GHMSKPQTQGLAKDAWEIPRESLRLEVKLGQGCFGEVWMGTWNGTTRVAIKTLKPGTMSPEAFLQEAQVMKKLRHEKLVQLYAVVSEEPIYIVTEYMSKGSLLDFLKGEMGKYLRLPQLVDMAAQIASGMAYVERMNYVHRDLRAANILVGENLVCKVADFGLARLIEDNEYTARQGAKFPIKWTAPEAALYGRFTIKSDVWSFGILLTELTTKGRVPYPGMVNREVLDQVERGYRMPCPPECPESLHDLMCQCWRKDPEERPTFEYLQAFLEDYFTSTEPQYQPGENL
REPLY=user@mail.com
STOICHIOMETRY=A2
```

**Example: heteromer**

```
TARGET=targetID_heterotetramer
SEQUENCE=>subunit1|
MGSKKLKRVGLSQELCDRLSRHQILTCQDFLCLSPLELMKVTGLSYRGVHELLCMVSRACAPKMQTAYGIKAQRSADFSPAFLSTTLSALDEALHGGVACGSLTEITGPPGCGKTQFCIMMSILATLPTNMGGLEGAVVYIDTESAFSAERLVEIAESRFPRYFNTEEKLLLTSSKVHLYRELTCDEVLQRIESLEEEIISKGIKLVILDSVASVVRKEFDAQLQGNLKERNKFLAREASSLKYLAEEFSIPVILTNQITTHLSGALASQADLVSPADDLSLSEGTSGSSCVIAALGNTWSHSVNTRLILQYLDSERRQILIAKSPLAPFTSFVYTIKEEGLVLQAYGNS
>subunit2|
MRGKTFRFEMQRDLVSFPLSPAVRVKLVSAGFQTAEELLEVKPSELSKEVGISKAEALETLQIIRRECLTNKPRYAGTSESHKKCTALELLEQEHTQGFIITFCSALDDILGGGVPLMKTTEICGAPGVGKTQLCMQLAVDVQIPECFGGVAGEAVFIDTEGSFMVDRVVDLATACIQHLQLIAEKHKGEEHRKALEDFTLDNILSHIYYFRCRDYTELLAQVYLLPDFLSEHSKVRLVIVDGIAFPFRHDLDDLSLRTRLLNGLAQQMISLANNHRLAVILTNQMTTKIDRNQALLVPALGESWGHAATIRLIFHWDRKQRLATLYKSPSQKECTVLFQIKPQGFRDTVVTSACSLQTEGSLSTRKRSRDPEEEL
>subunit3|
MGVLRVGLCPGLTEEMIQLLRSHRIKTVVDLVSADLEEVAQKCGLSYKALVALRRVLLAQFSAFPVNGADLYEELKTSTAILSTGIGSLDKLLDAGLYTGEVTEIVGGPGSGKTQVCLCMAANVAHGLQQNVLYVDSNGGLTASRLLQLLQAKTQDEEEQAEALRRIQVVHAFDIFQMLDVLQELRGTVAQQVTGSSGTVKVVVVDSVTAVVSPLLGGQQREGLALMMQLARELKTLARDLGMAVVVTNHITRDRDSGRLKPALGRSWSFVPSTRILLDTIEGAGASGGRRMACLAKSSRQPTGFQEMVDIGTWGTSEQSATLQGDQT
>subunit4|
GCSAFHRAESGTELLARLEGRSSLKEIEPNLFADEDSPVHGDILEFHGPEGTGKTEMLYHLTARCILPKSEGGLEVEVLFIDTDYHFDMLRLVTILEHRLSQSSEEIIKYCLGRFFLVYCSSSTHLLLTLYSLESMFCSHPSLCLLILDSLSAFYWIDRVNGGESVNLQESTLRKCSQCLEKLVNDYRLVLFATTQTIMQKASSSSEEPSHASRRLCDVDIDYRPYLCKAWQQLVKHRMFFSKQDDSQSSNQFSLVSRCLKSNSLKKHFFIIGESGVEFC

REPLY=user@mail.com
STOICHIOMETRY=A1B1C1D1
```

## Server responses

The server will respond as soon as it detects a new query by sending a confirmation to the sender address (not necessarily the `REPLY` address).

When the target has been modelled, it sends the models as PDB coordinates pasted in plain text to a number of emails (one per model) to the email address specified in the `REPLY` address (not the sender address).

## Uploading results to a separate server

It is also possible to upload the AlphaFold outputs to a separate server for backup or so that users can access MSAs, pickle files etc. The access must be configured through public/private key and be passwordless (e.g. the server must be able to run rsync to the server without password prompt).

```
snakemake -j 1--rerun-incomplete --cores 1 upload_msas # upload MSAs only
snakemake -j 1--rerun-incomplete --cores 1 upload_models # upload models, pickle files
```
