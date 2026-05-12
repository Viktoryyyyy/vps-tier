# Secret Policy

Never commit private keys, UUIDs, API tokens, subscription outputs, certbot material, users.json, runtime env files, rendered production configs, or backups.

Allowed in Git: documentation, placeholder templates, non-secret manifests, and redacted observed-state notes.

Runtime env contract variables may be documented by name only. Real UUIDs, private keys, certificate paths from production, tokens, client links, and rendered production configs remain forbidden in Git.
