localrules:
    send_acknowledgement,
    send_results,


rule send_acknowledgement:
    input:
        fasta="results/targets/{target}/{target}.fasta",
    output:
        ack="results/targets/{target}/.ack_sent",
    params:
        email="results/targets/{target}/sender_address",
        group_name=(
            lambda wildcards: config["CASP_groupname"]
            if is_monomer(
                f"results/targets/{wildcards.target}/{wildcards.target}.fasta"
            )
            else config["CASP_groupname_multi"]
        ),
    message:
        "SENDING ACKNOWLEDGEMENT TO {params.email}"
    run:
        success = send_ack(params.email, wildcards.target, params.group_name)
        if success:
            Path(output.ack).touch()


rule send_results:
    input:
        email_file="results/targets/{target}/mail_results_to",
        models="results/AF_models/{target}/ranked_4.header.pdb",
    output:
        models_sent="results/targets/{target}/.models_sent",
    params:
        group_name=(
            lambda wildcards: config["CASP_groupname"]
            if is_monomer(
                f"results/targets/{wildcards.target}/{wildcards.target}.fasta"
            )
            else config["CASP_groupname_multi"]
        ),
    message:
        "SUBMITTING MODELS"
    run:
        success = True
        for model in glob.glob(
            f"results/AF_models/{wildcards.target}/ranked_*.header.pdb"
        ):
            success = success and send_models(
                input.email_file, wildcards.target, model, params.group_name
            )
        if success:
            Path(output.models_sent).touch()
