#!/bin/bash
# pgsodium / Vault root key. Stored with the data (the official image keeps it in
# /etc/postgresql-custom, which is read-only here). Losing it makes Vault secrets unreadable.
set -euo pipefail

KEY_FILE=/home/container/postgres/pgsodium_root.key

if [[ ! -f "${KEY_FILE}" ]]; then
    umask 077
    head -c 32 /dev/urandom | od -A n -t x1 | tr -d ' \n' > "${KEY_FILE}"
fi
cat "${KEY_FILE}"
