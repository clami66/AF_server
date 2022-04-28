localrules:
    add_headers,


rule run_alphafold:
    input:
        fasta="results/targets/{target}/{target}.fasta",
        ack="results/targets/{target}/.ack_sent",
    output:
        models="results/AF_models/{target}/ranked_4.pdb",
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
    resources:
        ntasks=lambda wildcards: get_n_cores(
            f"results/targets/{wildcards.target}/{wildcards.target}.fasta"
        ),
        mem_mb=120000,
        gpus=lambda wildcards: get_n_gpus(
            f"results/targets/{wildcards.target}/{wildcards.target}.fasta"
        ),
        time=4320,
        mail_user=config["server_address"],
    conda:
        "envs/environment.yaml"
    message:
        "RUNNING ALPHAFOLD ON {resources.ntasks} CORES, {resources.gpus} GPUs"
    log:
        "logs/alphafold_run/{target}.log",
    benchmark:
        "benchmarks/alphafold_run/{target}.tsv"
    shell:
        "export TF_FORCE_UNIFIED_MEMORY=1;"
        "export XLA_PYTHON_CLIENT_MEM_FRACTION={resources.gpus};"
        "python {params.alphafold} --flagfile {params.flagfile} --output_dir results/AF_models --fasta_paths {input.fasta} &> {log}"
    
    
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
    shell:
        """
                        i=1
                        for model in {params.model_dir}/ranked_[0-4].pdb; do
                            basename=$(basename $model .pdb)
                            cat > {params.model_dir}/$basename.header.pdb <<- xx
        PFRMAT TS
        TARGET {wildcards.target}
        AUTHOR {params.groupid}
        METHOD Vanilla AlphaFold v2.2
        METHOD Databases as downloaded by AF2 scripts
        MODEL  $i
        PARENT N/A
        xx
                            # need to remove excess columns so that email submissions doesn't get line-wrapped
                            cat $model | cut -c -65 >> {params.model_dir}/$basename.header.pdb
                            sed -i 's/TER[ A-Z0-9]*/TER/g' {params.model_dir}/$basename.header.pdb
                            # need to add PARENT tag between inter-chain TER and next ATOM
                            sed -z 's/TER\\nATOM/TER\\nPARENT N\/A\\nATOM/g' {params.model_dir}/$basename.header.pdb > {params.model_dir}/$basename.header.ter.pdb
                            mv {params.model_dir}/$basename.header.ter.pdb {params.model_dir}/$basename.header.pdb
                            i=$((i+1))
                        done
        """
