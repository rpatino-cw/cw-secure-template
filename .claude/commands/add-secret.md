# Safely store an API key or secret.
# Usage: /project:add-secret

Guide the user through storing a secret safely. NEVER accept or display secret values.

## Steps

1. Tell the user to run `make add-secret` in their terminal
2. Explain: "This stores your secret in .env with hidden input. The value is never visible."
3. After they've stored it, write the code that references it:
   - Python: `os.environ["VARIABLE_NAME"]`
   - Go: `os.Getenv("VARIABLE_NAME")`
4. If they try to paste a key directly to you, refuse:
   "I can't accept secrets directly — they'd appear in the conversation history. Run `make add-secret` instead."

## For config files

If they have a .json, .pem, or .key file, tell them to run `make add-config` instead.
This stores the file in `.secrets/` (gitignored).
