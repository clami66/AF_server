import os
import re
import sys
import glob
import email
import imaplib
import smtplib

##### load config #####
configfile: "config/config.yaml"
if workflow.use_env_modules:
    configfile: "config/envmodules.yaml"

envvars:
    "EMAIL_PASS"

def get_messages(whitelist):
    server = config["mail_server"]
    username = config["server_address"]
    password = os.environ["EMAIL_PASS"]
    
    emails = []
    email_regex = r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"
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
    return "TARGET=" in email_body and "REPLY-E-MAIL=" in email_body

def parse_casp_target(email_body):
    target_name = re.findall("TARGET=([a-zA-Z0-9]+)", email_body)[0]
    reply_email = re.findall("REPLY-E-MAIL=([a-zA-Z0-9@.]+)", email_body)[0]
    stoichiometry = re.findall("STOICHIOMETRY=([a-zA-Z0-9]+)", email_body)[0] if "STOICHIOMETRY" in email_body else "A1" 
    chain_units = zip(stoichiometry[0::2], stoichiometry[1::2]) # e.g. A3B1 -> [('A', '3'), ('B', '1')]
    
    heteromer = re.findall(r'(>[a-zA-Z0-9]+.* [|])[\s]+([A-Z]+)', email_body)
    mono_or_homomer = re.findall("SEQUENCE=([A-Z]+)", email_body)
    fasta = []
    
    if mono_or_homomer:
        n_homomers = int(list(chain_units)[0][1])
        for homomer in range(n_homomers):
            fasta.append(f"> {target_name}_{homomer}")
            fasta.append(mono_or_homomer[0])
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
        try:
            os.mkdir(f"results/targets/{target_name}")
        except Exception as a:
            print(a)
        
        with open(f"results/targets/{target_name}/{target_name}.fasta", "w") as out:
            for line in fasta:
                out.write(f"{line}\n")
                
        with open(f"results/targets/{target_name}/mail_results_to", "w") as out:
            out.write(f"{reply_email}\n")

    return target_name

def parse_target(email_body):
    return "foo" #TODO implement this

def check_email_for_new_targets():

    new_targets = []
    whitelist_file = config["whitelist"]
    whitelist = [address.strip() for address in open(whitelist_file, "r").readlines()]
    emails = get_messages(whitelist)
    
    for (sender, subject, body) in emails:
        if is_casp_target(str(body)):
            target_name = parse_casp_target(str(body))
            new_targets.append(target_name)
        elif ">" in str(body): # this is some other kind of target
            target_name = parse_target(str(body))
            new_targets.append(target_name)
        else: # email from sender in whitelist but not a target?
            pass
    
    return new_targets

def send_email(mail_from, mail_to, mail_subject, mail_body):
    
    mail_message = f"""
    From: {mail_from}
    To: {mail_to}
    Subject: {mail_subject}

    {mail_body}
    """
    mail_server = config["mail_server"]

    try:
        server = smtplib.SMTP(mail_server)
        server.sendmail(mail_from, mail_to, mail_subject, mail_message)
        server.quit()
        return True
    except:
        return False

def send_acknowledgement(to, target_name):
    mail_from = config["server_address"]
    server_name = config["server_name"]
    
    mail_subject = f"{target_name} - query received by {server_name}"
    mail_body = ""
    mail_to = ', '.join(to)

    success = send_email(mail_from, mail_to, mail_subject, mail_body)
    return success

def check_fs_for_new_targets():
    fastas = glob.glob("results/targets/*/*.fasta")
    return [os.path.basename(fasta).rstrip(".fasta") for fasta in fastas]

def is_monomer(fasta_path):
    n_sequences=0
    with open(fasta_path, "r") as fasta:
        for line in fasta:
            if ">" in line:
                n_sequences += 1
                
    return n_sequences == 1


def get_n_gpus(fasta_file):
    #TODO: check that the n_gpus make sense
    n_gpus = 1
    fasta_sequence = ""
    with open(fasta_file, "r") as fasta:
        for line in fasta:
            if not line.startswith(">"):
                fasta_sequence += line
    fasta_length = len(fasta_sequence)
    
    if fasta_length < 400:
        pass
    elif fasta_length < 1000:
        n_gpus = 2
    elif fasta_length < 2000:
        n_gpus = 3
    elif fasta_length < 4000:
        n_gpus = 4
    else:
        n_gpus = 8
    
    return n_gpus

def get_n_cores(fasta_file):
    return get_n_gpus(fasta_file) * 16

def read_json(json_path):
    js = json.loads(open(json_path).read())
    model_order = js["order"]
    
    return model_order

##############################
# Input collection function
##############################
def emails(wildcards):
    return expand("results/targets/{target}/.done", target=check_email_for_new_targets())

def af_targets(wildcards):
    return expand("results/AF_models/{target}/ranking_debug.json", target=check_fs_for_new_targets())
