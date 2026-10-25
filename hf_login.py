from getpass import getpass
from huggingface_hub import login
login(token=getpass("Hugging Face read token (hidden): "), add_to_git_credential=False)
print("Login complete.")
