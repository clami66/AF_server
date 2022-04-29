localrules:
    data_upload,
    msa_upload,
    model_upload,
    pkl_reduction,

rule data_upload:
    input:
        models="results/AF_models/{target}/ranked_4.pdb",
    output:
        data_uploaded="results/targets/{target}/.data_uploaded",
    params:
        data_dir="results/AF_models/{target}",
        server_user=config["data_server_user"],
        server_address=config["data_server_address"],
        server_folder=config["data_server_folder"],
    log:
        "logs/rsync/{target}.log",
    shell:
        "cd {params.data_dir}/msas; tar -zcvf ../msas.tar.gz *; cd -;"
        "cd {params.data_dir}; tar -zcvf models.tar.gz $(ls ranked_*.pdb | grep -v header); cd -;"
        "rsync -av {params.data_dir}/msas.tar.gz {params.data_dir}/models.tar.gz {params.server_user}@{params.server_address}:{params.server_folder}/{wildcards.target}/ &> {log};"
        "touch {output.data_uploaded};"


rule msa_upload:
    input:
        features="results/AF_models/{target}/features.pkl",
    output:
        msas_uploaded="results/targets/{target}/.msas_uploaded",
    params:
        data_dir="results/AF_models/{target}",
        server_user=config["data_server_user"],
        server_address=config["data_server_address"],
        server_folder=config["data_server_folder"],
    log:
        "logs/rsync/{target}_msas.log",
    shell:
        "cd {params.data_dir}/msas; tar -zcvf ../msas.tar.gz *; cd -;"
        "rsync -av {params.data_dir}/msas.tar.gz {params.server_user}@{params.server_address}:{params.server_folder}/{wildcards.target}/ &> {log};"
        "touch {output.msas_uploaded};"


rule model_upload:
    input:
        models="results/AF_models/{target}/ranked_4.pdb",
        pickles="results/AF_models/{target}/ranked_4.pkl",
    output:
        models_uploaded="results/targets/{target}/.models_uploaded",
    params:
        data_dir="results/AF_models/{target}",
        server_user=config["data_server_user"],
        server_address=config["data_server_address"],
        server_folder=config["data_server_folder"],
    log:
        "logs/rsync/{target}_msas.log",
    shell:
        "cd {params.data_dir}; tar -zcvf models.tar.gz $(ls ranked_*.pdb | grep -v header); tar -zcvf pickles.tar.gz $(ls ranked_*.pkl); cd -;"
        "rsync -av {params.data_dir}/models.tar.gz {params.data_dir}/pickles.tar.gz {params.server_user}@{params.server_address}:{params.server_folder}/{wildcards.target}/ &> {log};"
        "touch {output.models_uploaded};"


rule pkl_reduction:
    input:
        ranking="results/AF_models/{target}/ranking_debug.json",
    output:
        pickles="results/AF_models/{target}/ranked_4.pkl",
    resources:
        mem_mb=config["mem_mb"]
    run:
        model_order=get_model_order(input.ranking)
        for rank, model in enumerate(model_order):
            reduce_pkl(f"results/AF_models/{wildcards.target}/result_{model}.pkl", rank)
