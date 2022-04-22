import os
import re
import sys
import glob
import email
import imaplib
import base64
import logging
import mimetypes
import pickle

##### load config #####
configfile: "config/config.yaml"
envvars:
    "EMAIL_PASS"

def get_messages(whitelist):
    server = config["mail_server"]
    username = config["mail_username"]
    password = os.environ["EMAIL_PASS"]
    
    emails = []
    email_regex = r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"
    # connect to the server and go to its inbox
    mail = imaplib.IMAP4_SSL(server)
    mail.login(username, password)
    # we choose the inbox but you can select others
    mail.select('inbox')

    # we'll search using the ALL criteria to retrieve
    # every message inside the inbox
    # it will return with its status and a list of ids
    status, data = mail.search(None, 'ALL')
    # the list returned is a list of bytes separated
    # by white spaces on this format: [b'1 2 3', b'4 5 6']
    # so, to separate it first we create an empty list
    mail_ids = []
    # then we go through the list splitting its blocks
    # of bytes and appending to the mail_ids list
    for block in data:
        # the split function called without parameter
        # transforms the text or bytes into a list using
        # as separator the white spaces:
        # b'1 2 3'.split() => [b'1', b'2', b'3']
        mail_ids += block.split()

    # now for every id we'll fetch the email
    # to extract its content
    for i in mail_ids:
        # the fetch function fetch the email given its id
        # and format that you want the message to be
        status, data = mail.fetch(i, '(RFC822)')

        # the content data at the '(RFC822)' format comes on
        # a list with a tuple with header, content, and the closing
        # byte b')'
        for response_part in data:
            # so if its a tuple...
            if isinstance(response_part, tuple):
                # we go for the content at its second element
                # skipping the header at the first and the closing
                # at the third
                message = email.message_from_bytes(response_part[1])

                # with the content we can extract the info about
                # who sent the message and its subject
                sender = message['from']
                subject = message['subject']

                # then for the text we have a little more work to do
                # because it can be in plain text or multipart
                # if its not plain text we need to separate the message
                # from its annexes to get the text
                if message.is_multipart():
                    mail_content = ''

                    # on multipart we have the text message and
                    # another things like annex, and html version
                    # of the message, in that case we loop through
                    # the email payload
                    for part in message.get_payload():
                        # if the content type is text/plain
                        # we extract it
                        if part.get_content_type() == 'text/plain':
                            mail_content += part.get_payload()
                else:
                    # if the message isn't multipart, just extract it
                    mail_content = message.get_payload()

                emails.append((sender, subject, mail_content))
    return emails

def check_email_for_new_targets():

    new_targets = []
    whitelist_file = config["whitelist"]
    whitelist = [address.strip() for address in open(whitelist_file, "r").readlines()]
    emails = get_messages(whitelist)
    
    for (sender, subject, body) in emails:
        if "TARGET=" in str(body): # this is a casp target
            target_name = parse_casp_target(str(body))
            new_targets.append(target_name)
    
    return new_targets

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

def is_monomer(fasta_path):
    n_sequences=0
    with open(fasta_path, "r") as fasta:
        for line in fasta:
            if ">" in line:
                n_sequences += 1
                
    return n_sequences == 1

def check_fs_for_new_targets():
    fastas = glob.glob("results/targets/*/*.fasta")
    return [os.path.basename(fasta).rstrip(".fasta") for fasta in fastas]

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
