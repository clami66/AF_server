localrules:
    add_headers,


rule run_alphafold:
    input:
        fasta="results/targets/{target}/{target}.fasta",
        ack="results/targets/{target}/.ack_sent",
    output:
        models="results/AF_models/{target}/ranked_4.pdb",
        ranking="results/AF_models/{target}/ranking_debug.json"
    params:
        alphafold=expand(
            "{install_dir}/run_alphafold.py", install_dir={config["AF_install_dir"]}
        ),
        flagfile=(
            lambda wildcards: config["monomer_flagfile"]
            if is_monomer(
                f"results/targets/{wildcards.target}/{wildcards.target}.fasta"
            )
            else config["multimer_flagfile"]
        ),
        lock_file="results/AF_models/{target}/.slurm_running",
    resources:
        ntasks=lambda wildcards: get_n_cores(
            f"results/targets/{wildcards.target}/{wildcards.target}.fasta"
        ),
        gpus=lambda wildcards: min(
            get_n_gpus(f"results/targets/{wildcards.target}/{wildcards.target}.fasta"),
            config["max_gpus"],
        ),
        mem_mb=lambda wildcards: config["mem_mb"] * min(
	    get_n_gpus(f"results/targets/{wildcards.target}/{wildcards.target}.fasta"),
            config["gpus_per_node"],
        ),
        time=config["walltime"],
        nodes=lambda wildcards: get_n_gpus(f"results/targets/{wildcards.target}/{wildcards.target}.fasta") // config["gpus_per_node"],
    conda:
        "../envs/environment.yaml"
    message:
        "RUNNING ALPHAFOLD ON {resources.ntasks} CORES, {resources.gpus} GPUs"
    log:
        "logs/alphafold_run/{target}.log",
    benchmark:
        "benchmarks/alphafold_run/{target}.tsv"
    shell:
        "export TF_FORCE_UNIFIED_MEMORY=1;"
        "export XLA_PYTHON_CLIENT_MEM_FRACTION=$(({resources.gpus}+2));"
        "touch {params.lock_file};"
        "python {params.alphafold} --flagfile {params.flagfile} --output_dir results/AF_models --fasta_paths {input.fasta} &> {log};"
        "rm {params.lock_file};"


rule add_headers:
    input:
        fasta="results/targets/{target}/{target}.fasta",
        models="results/AF_models/{target}/ranked_4.pdb",
    output:
        models="results/AF_models/{target}/ranked_4.header.pdb",
    params:
        groupid=(
            lambda wildcards: config["CASP_groupn"]
            if is_monomer(
                f"results/targets/{wildcards.target}/{wildcards.target}.fasta"
            )
            else config["CASP_groupn_multi"]
        ),
        model_dir="results/AF_models/{target}/",
        header_script="workflow/scripts/cat_header.sh"
    shell:
        """
        i=1
        for model in {params.model_dir}/ranked_[0-4].pdb; do
            basename=$(basename $model .pdb)
            {params.header_script} {wildcards.target} {params.groupid} $i > {params.model_dir}/$basename.header.pdb
            
            # cat PDB coordinates removing excess columns to avoid line wrapping in emails
            cat $model | cut -c -65 >> {params.model_dir}/$basename.header.pdb
            sed -i 's/TER[ A-Z0-9]*/TER/g' {params.model_dir}/$basename.header.pdb
            
            # need to add PARENT tag between inter-chain TER and next ATOM
            sed -z 's/TER\\nATOM/TER\\nPARENT N\/A\\nATOM/g' {params.model_dir}/$basename.header.pdb > {params.model_dir}/$basename.header.ter.pdb
            mv {params.model_dir}/$basename.header.ter.pdb {params.model_dir}/$basename.header.pdb
            i=$((i+1))
        done
        """
