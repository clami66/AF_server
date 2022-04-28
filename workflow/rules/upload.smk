localrules:
    data_upload,
    msa_upload,
    model_upload,


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
        "touch results/targets/{wildcards.target}/.data_uploaded;"


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
        "touch results/targets/{wildcards.target}/.msas_uploaded;"


rule model_upload:
    input:
        models="results/AF_models/{target}/ranked_4.pdb",
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
        "cd {params.data_dir}; tar -zcvf models.tar.gz $(ls ranked_*.pdb | grep -v header); cd -;"
        "rsync -av {params.data_dir}/models.tar.gz {params.server_user}@{params.server_address}:{params.server_folder}/{wildcards.target}/ &> {log};"
        "touch results/targets/{wildcards.target}/.models_uploaded;"
