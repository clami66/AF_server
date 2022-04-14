import os
import re
import sys
import email
import imaplib
import base64
import logging
import mimetypes
import pickle
from email.mime.text import MIMEText
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient import errors
from googleapiclient.discovery import build
from bs4 import BeautifulSoup

##### load config #####
configfile: "config/config.yaml"

def get_service():
    """Gets an authorized Gmail API service instance.

    Returns:
        An authorized Gmail API service instance..
    """    

    # If modifying these scopes, delete the file token.pickle.
    SCOPES = [
        'https://www.googleapis.com/auth/gmail.readonly',
        'https://www.googleapis.com/auth/gmail.send',
    ]

    credential_file = config["credentials"]
    creds = None
    # The file token.pickle stores the user's access and refresh tokens, and is
    # created automatically when the authorization flow completes for the first
    # time.
    if os.path.exists('token.pickle'):
        with open('token.pickle', 'rb') as token:
            creds = pickle.load(token)

    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        #if creds and creds.expired and creds.refresh_token:
         #   creds.refresh(Request())
        #else:
        flow = InstalledAppFlow.from_client_secrets_file(
            credential_file, SCOPES)
        creds = flow.run_local_server(port=0)
        # Save the credentials for the next run
        with open('token.pickle', 'wb') as token:
            pickle.dump(creds, token)

    service = build('gmail', 'v1', credentials=creds)
    return service

def send_message(service, sender, message):
  """Send an email message.

  Args:
    service: Authorized Gmail API service instance.
    user_id: User's email address. The special value "me"
    can be used to indicate the authenticated user.
    message: Message to be sent.

  Returns:
    Sent Message.
  """
  try:
    sent_message = (service.users().messages().send(userId=sender, body=message)
               .execute())
    logging.info('Message Id: %s', sent_message['id'])
    return sent_message
  except errors.HttpError as error:
    logging.error('An HTTP error occurred: %s', error)

def create_message(sender, to, subject, message_text):
  """Create a message for an email.

  Args:
    sender: Email address of the sender.
    to: Email address of the receiver.
    subject: The subject of the email message.
    message_text: The text of the email message.

  Returns:
    An object containing a base64url encoded email object.
  """
  message = MIMEText(message_text)
  message['to'] = to
  message['from'] = sender
  message['subject'] = subject
  s = message.as_string()
  b = base64.urlsafe_b64encode(s.encode('utf-8'))
  return {'raw': b.decode('utf-8')}


def get_messages(whitelist):
    username = config["email_username"]
    emails = []
    email_regex = r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"

    try:
        service = get_service()
        message_list = (service.users().messages().list(userId=username)
                .execute())
    except errors.HttpError as error:
        logging.error('An HTTP error occurred: %s', error)
        
    messages = message_list.get('messages')
  
    # messages is a list of dictionaries where each dictionary contains a message id.
  
    # iterate through all the messages
    for msg in messages:
        # Get the message from its id
        txt = service.users().messages().get(userId=username, id=msg['id']).execute()
        #print(txt)
        try:
            # Get value of 'payload' from dictionary 'txt'
            payload = txt['payload']
            headers = payload['headers']
            # Look for Subject and Sender Email in the headers
            for d in headers:
                if d['name'] == 'Subject':
                    subject = d['value']
                if d['name'] == 'From':
                    sender = d['value']
                    sender = re.search(email_regex, sender).group(0)
                                        
            if sender in whitelist:
                # The Body of the message is in Encrypted format. So, we have to decode it.
                # Get the data and decode it with base 64 decoder.
                parts = payload.get('parts')[0]
                data = parts['body']['data']
                data = data.replace("-","+").replace("_","/")
                decoded_data = base64.b64decode(data)
    
                # Now, the data obtained is in lxml. So, we will parse 
                # it with BeautifulSoup library
                soup = BeautifulSoup(decoded_data , "lxml")
                body = soup.find("body").findChildren(recursive=False)
                emails.append((sender, subject, body))
        except Exception as e:
            print(e)
    
    return emails

def check_email_for_new_targets():

    whitelist_file = config["whitelist"]
    whitelist = [address.strip() for address in open(whitelist_file, "r").readlines()]
    emails = get_messages(whitelist)
    
    for (sender, subject, body) in emails:
#        print(str(body))
        if "TARGET=" in str(body): # this is a casp target
            target_name = parse_casp_target(str(body))
    
    return []

def parse_casp_target(email_body):
    target_name = re.findall("TARGET=([a-zA-Z0-9]+)", email_body)[0]
    reply_email = re.findall("REPLY-E-MAIL=([a-zA-Z0-9@.]+)", email_body)[0]
    stoichiometry = re.findall("STOICHIOMETRY=([a-zA-Z0-9]+)", email_body)[0] if "STOICHIOMETRY" in email_body else "A1" 
    chain_units = zip(stoichiometry[0::2], stoichiometry[1::2]) # e.g. A3B1 -> [('A', '3'), ('B', '1')]
    print(email_body)
    heteromer = re.findall("(>[a-zA-Z0-9]+.* [|][ ]*)\n([A-Z]+)", email_body)
    mono_or_homomer = re.findall("SEQUENCE=([A-Z]+)", email_body)
    fasta = []
    
    if mono_or_homomer:
        n_homomers = int(list(chain_units)[0][1])
        for homomer in range(n_homomers):
            fasta.append(f"> {target_name}_{homomer}")
            fasta.append(mono_or_homomer[0])
    elif heteromer:
        for i, (chain, units) in enumerate(chain_units):
            this_chain_header = multimer[i][0]
            this_chain_sequence = multimer[i][1]
            
            for homo_repeat in range(int(units)):
                fasta.append(f"{this_chain_header}_{homo_repeat}")
                fasta.append(this_chain_sequence)
    else:
        print("Wrong query format")
        
    print("\n".join(fasta))
    return target_name
            
##############################
# Input collection function
##############################
def all_input(wildcards):
    return expand("results/{target}/.{target}_done", target=check_email_for_new_targets())
