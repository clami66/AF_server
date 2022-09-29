import os
import re
import sys
import math
import glob
import pickle
import email
import imaplib
import smtplib
from pathlib import Path
from email.message import EmailMessage


##### load config #####
configfile: "config/config.yaml"


if workflow.use_env_modules:

    configfile: "config/envmodules.yaml"


envvars:
    "EMAIL_PASS",


IS_CASP = False


def get_messages():
    server = config["mail_server"]
    username = config["server_address"]
    password = os.environ["EMAIL_PASS"]

    emails = []
    mail = imaplib.IMAP4_SSL(server)
    mail.login(username, password)
    mail.select("inbox")

    status, data = mail.search(None, "ALL")
    mail_ids = []
    for block in data:
        mail_ids += block.split()

    for i in mail_ids:
        status, data = mail.fetch(i, "(RFC822)")

        for response_part in data:
            if isinstance(response_part, tuple):
                message = email.message_from_bytes(response_part[1])

                sender = message["from"]
                subject = message["subject"]
                if message.is_multipart():
                    mail_content = ""
                    for part in message.get_payload():
                        if part.get_content_type() == "text/plain":
                            mail_content += part.get_payload()
            else:
                mail_content = message.get_payload()

                emails.append((sender, subject, mail_content))
    return emails


def is_casp_target(email_body):
    IS_CASP = "TARGET=" in email_body
    return IS_CASP


def parse_casp_target(sender, email_body):
    target_name = re.findall("TARGET=([a-zA-Z0-9]+)", email_body)[0]
    reply_email = re.findall("REPLY[\-EMAIL]*=([a-zA-Z0-9@.]+)", email_body)[0]

    stoichiometry = "A1" # A1 is the default in case the field is not in the email
    re_sto = re.findall("STOICHIOMETRY=([a-zA-Z0-9:]+)", email_body)
    if re_sto:
        stoichiometry = re_sto[0]

    chain_units = re.findall("([A-Z]+)([0-9]+)", stoichiometry)  # e.g. A16B8 -> [('A', '16'), ('B', '8')]
    heteromer = re.findall(r"(>[ a-zA-Z0-9]+.*[|])[\s]+([A-Z]+)", email_body)

    #mono_or_homomer = re.findall("SEQUENCE=([A-Z]+)", email_body)
    mono_or_homomer = re.findall("SEQUENCE=([A-Z\s]+)REPLY", email_body)
    fasta = []
    n_homomers = 1
    if mono_or_homomer:
        n_homomers = int(list(chain_units)[0][1])
        for homomer in range(n_homomers):
            fasta.append(f"> {target_name}_{homomer}")
            fasta.append(re.sub("\s", "", mono_or_homomer[0]))
            #fasta.append(mono_or_homomer[0])
    elif heteromer:
        for i, (chain, units) in enumerate(chain_units):
            this_chain_header = heteromer[i][0]
            this_chain_sequence = heteromer[i][1]

            for homo_repeat in range(int(units)):
                fasta.append(f"{this_chain_header}_{homo_repeat}")
                fasta.append(this_chain_sequence)
    else:
        print("Wrong query format")
    if fasta:
        print(stoichiometry, heteromer)
        try:
            os.makedirs(f"results/targets/{target_name}", exist_ok=True)
        except Exception as a:
            print(a)

        fasta_out = f"results/targets/{target_name}/{target_name}.fasta"
        if not os.path.isfile(
            fasta_out
        ):  # avoid triggering re-execution if file was already there
            with open(fasta_out, "w") as out:
                for line in fasta:
                    out.write(f"{line}\n")

            # results are sent to address specified in email body, not to sender
            with open(f"results/targets/{target_name}/mail_results_to", "w") as out:
                out.write(f"{reply_email}\n")
            # acknowledgement is always sent back to sender
            with open(f"results/targets/{target_name}/sender_address", "w") as out:
                out.write(f"{sender}\n")

        # homodimers etc, need to write the monomer fasta target as well
        if n_homomers > 1:
            fasta_out = f"results/targets/{target_name}_A1/{target_name}_A1.fasta"
            if not os.path.isfile(
            fasta_out
            ):
                try:
                    os.makedirs(f"results/targets/{target_name}_A1", exist_ok=True)
                except Exception as a:
                    print(a)

                with open(fasta_out, "w") as out:
                    for line in fasta[:2]:
                        out.write(f"{line}\n")

                with open(f"results/targets/{target_name}_A1/mail_results_to", "w") as out:
                    out.write(f"{reply_email}\n")
                with open(f"results/targets/{target_name}_A1/sender_address", "w") as out:
                    out.write(f"{sender}\n")
            return [target_name, target_name + "_A1"]

    return target_name


def check_email_for_new_targets():

    new_targets = []
    whitelist_file = config["whitelist"]
    whitelist = [address.strip() for address in open(whitelist_file, "r").readlines()]
    emails = get_messages()
    email_regex = r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"

    for (sender, subject, body) in emails:
        if re.findall(email_regex, sender)[0] in whitelist:
            if type(body) is list:
                body = body[0]
            if is_casp_target(str(body)):
                sender_email = re.findall(email_regex, sender)[0]
                target_name = parse_casp_target(sender_email, str(body))
                if type(target_name) is list:
                    new_targets.extend(target_name)
                else:
                    new_targets.append(target_name)
                print(new_targets)
            else:  # email from sender in whitelist but not a target?
                pass

    return new_targets


def send_email(mail_from, mail_to, mail_subject, mail_body):

    mail_server = config["mail_server"]
    username = config["server_address"]
    password = os.environ["EMAIL_PASS"]
    mail_to_string = ", ".join(mail_to)

    msg = EmailMessage()
    msg["From"] = mail_from
    msg["To"] = mail_to_string
    msg["Subject"] = mail_subject
    msg.set_content(mail_body)

    try:
        mail = smtplib.SMTP(mail_server, 587)
        mail.connect(mail_server, 587)
        mail.ehlo()
        mail.starttls()
        mail.login(username, password)
        mail.send_message(msg)
        mail.quit()
        return True
    except Exception as e:
        print(e)
        return False


def send_ack(to, target_name, group_name):
    mail_from = config["server_address"]

    mail_subject = f"{target_name} - query received by {group_name}"
    mail_body = ""
    mail_to = (
        [to] if "@" in to else [address.strip() for address in open(to).readlines()]
    )
    success = send_email(mail_from, mail_to, mail_subject, mail_body)
    return success


def send_models(to_file, target_name, models, group_name):
    mail_from = config["server_address"]
    target_name = re.sub("_A1", "", target_name) # monomer version of homomer
    mail_subject = f"{target_name} - {group_name}"
    mail_body = open(models).read()
    mail_to = [address.strip() for address in open(to_file).readlines()]

    success = send_email(mail_from, mail_to, mail_subject, mail_body)
    return success


def check_fs_for_new_targets():
    fastas = glob.glob("results/targets/*/*.fasta")
    targets_with_fastas = [
        Path(fasta_path).parts[2] for fasta_path in fastas
    ]  # [os.path.basename(fasta).rstrip(".fasta") for fasta in fastas]
    # if a "msas" folder is in the target's results path it's likely being run on slurm, so we skip it
    slurm_running = glob.glob("results/AF_models/*/.slurm_running")
    targets_with_slurm = [Path(path).parts[2] for path in slurm_running]
    return [
        target for target in targets_with_fastas if not target in targets_with_slurm
    ]


def check_fs_for_data():
    return check_fs_for_models()


def check_fs_for_models():
    ended_runs = glob.glob("results/AF_models/*/ranked_4.pdb")
    return [os.path.basename(os.path.dirname(run)) for run in ended_runs]


def check_fs_for_msas():
    ended_msas = glob.glob("results/AF_models/*/features.pkl")
    return [os.path.basename(os.path.dirname(msa)) for msa in ended_msas]


def is_monomer(fasta_path):
    n_sequences = 0
    with open(fasta_path, "r") as fasta:
        for line in fasta:
            if ">" in line:
                n_sequences += 1

    return n_sequences == 1


def get_n_gpus(fasta_file):
    # TODO: check that the n_gpus make sense
    n_gpus = 1
    fasta_sequence = ""
    with open(fasta_file, "r") as fasta:
        for line in fasta:
            if not line.startswith(">"):
                fasta_sequence += line
    fasta_length = len(fasta_sequence)

    if fasta_length < 800:
        pass
    elif fasta_length < 1600:
        n_gpus = 2
    elif fasta_length < 2000:
        n_gpus = 3
    elif fasta_length < 3000:
        n_gpus = 4
    elif fasta_length < 5000:
        n_gpus = 8
    else:
        n_gpus = 16

    return n_gpus


def get_n_cores(fasta_file):
    return get_n_gpus(fasta_file) * config["n_cores_per_gpu"]


def get_model_order(json_path):
    js = json.loads(open(json_path).read())
    model_order = js["order"]

    return model_order


def reduce_pkl(pkl_path, ranking, keys=("predicted_aligned_error", "plddt", "ptm", "iptm", "ranking_confidence")):
    dirname = os.path.dirname(pkl_path)
    results_reduced = {}
    with open(pkl_path, "rb") as pkl:
        results = pickle.load(pkl)
        for key in keys:
            if key in results:
                results_reduced[key] = results[key]
    with open(f"{dirname}/ranked_{ranking}.pkl", "wb") as out_pkl:
        pickle.dump(results_reduced, out_pkl)
    return


##############################
# Input collection function
##############################
def all_input(wildcards):
    d = {
        "fasta": fasta_inputs(wildcards),
        "af": af_targets(wildcards),
    }
    return d


def fasta_inputs(wildcards):
    return expand(
        "results/targets/{target}/{target}.fasta", target=check_email_for_new_targets()
    )


def af_targets(wildcards):
    return expand(
        "results/targets/{target}/.models_sent", target=check_fs_for_new_targets()
    )


def uploads(wildcards):
    return expand("results/targets/{target}/.data_uploaded", target=check_fs_for_data())


def msa_uploads(wildcards):
    return expand("results/targets/{target}/.msas_uploaded", target=check_fs_for_msas())


def model_uploads(wildcards):
    return expand(
        "results/targets/{target}/.models_uploaded", target=check_fs_for_models()
    )
