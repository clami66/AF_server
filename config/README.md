```
# E-mail settings
server_address: "user@server.com" ### server mailbox address
mail_server: "server.com"  ### server mailbox domain
whitelist: "config/whitelist" ### The whitelist contains one email per line, only senders from the list will be allowed
# AF settings
AF_install_dir: "/proj/apps/alphafold" ### AlphaFold installation directory
monomer_flagfile: "/proj/apps/alphafold/flagfiles/monomer_full_dbs.flag" # monomer and multimer flag files paths
multimer_flagfile: "/proj/apps/alphafold/flagfiles/multimer_full_dbs.flag"
# resources settings, these override the slurm profile settings
mem_mb: 240000
walltime: 4320
max_gpus: 8
gpus_per_node: 8
n_cores_per_gpu: 16
# CASP settings, can be ignored if it is not a CASP server. Will show in PDB headers
CASP_groupn: "xxxx-yyyy-zzzz-wwww" # 
CASP_groupn_multi: "wwww-xxxx-yyyy-zzzz"
CASP_groupname: "af2-standard"
CASP_groupname_multi: "af2-multimer"
CASP_sender: "casp-meta@predictioncenter.org"
# for uploading results somewhere (passwordless).
# Results in invoking `rsync -av results/AF_models/{target}/[models,msas].tar.gz user@server.com:/path`
data_server_user: "user"
data_server_address: "server.com"
data_server_folder: "/path"
```
