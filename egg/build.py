"""Builds egg-supabase.json."""
import json
from datetime import datetime, timezone
from pathlib import Path

root = Path(__file__).parent

# Everything runs from the image; the installer only prepares the folders.
INSTALL = """#!/bin/ash
# Supabase ships entirely inside the Docker image, nothing is downloaded here.
mkdir -p /mnt/server/postgres /mnt/server/storage /mnt/server/snippets /mnt/server/functions
echo "Ready. Start the server to create the database and generate secrets.env."
"""


def var(name, env, desc, default, rules, editable=True, viewable=True):
    return {
        "name": name,
        "description": desc,
        "env_variable": env,
        "default_value": default,
        "user_viewable": viewable,
        "user_editable": editable,
        "rules": rules,
        "field_type": "text",
    }


BOOL = "required|string|in:true,false"

egg = {
    "_comment": "DO NOT EDIT: FILE GENERATED AUTOMATICALLY BY PTERODACTYL PANEL - PTERODACTYL.IO",
    "meta": {"version": "PTDL_v2", "update_url": None},
    "exported_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+00:00"),
    "name": "Supabase",
    "author": "bytessavvy@gmail.com",
    "description": (
        "Self-hosted Supabase (Postgres, Auth, REST, Realtime, Storage and Studio) in a single container, "
        "with an optional Cloudflare Tunnel for HTTPS without open ports. Secrets are generated on first "
        "start in secrets.env. Needs at least 2 GB of RAM."
    ),
    "features": None,
    "docker_images": {"Supabase": "ghcr.io/leonardorrc/pterodactyl-supabase:latest"},
    "file_denylist": [],
    "startup": "/opt/supabase/bin/start",
    "config": {
        "files": "{}",
        "startup": json.dumps({"done": "Supabase is ready"}),
        "logs": "{}",
        "stop": "^C",
    },
    "scripts": {
        "installation": {
            "script": INSTALL,
            "container": "ghcr.io/pterodactyl/installers:alpine",
            "entrypoint": "ash",
        }
    },
    "variables": [
        var("Public URL", "SUPABASE_PUBLIC_URL",
            "Public HTTPS address of Studio and the API, e.g. https://supabase.example.com. Used in auth emails, "
            "storage URLs and JWT issuer. Empty = http://localhost:<port>.",
            "", "nullable|url|max:255"),
        var("Site URL", "SITE_URL",
            "Your application's URL, where auth emails redirect to. Empty = the public URL.",
            "", "nullable|url|max:255"),
        var("Additional Redirect URLs", "ADDITIONAL_REDIRECT_URLS",
            "Comma-separated extra URLs allowed as auth redirects.",
            "", "nullable|string|max:2048"),
        var("Cloudflare Tunnel Token", "TUNNEL_TOKEN",
            "Token of a remotely-managed tunnel. In its Public Hostname use service HTTP and URL "
            "localhost:<server port>. Leave empty to run without the tunnel.",
            "", "nullable|string|max:2048"),
        var("Tunnel Protocol", "CF_PROTOCOL",
            "auto tries QUIC (UDP 7844) and falls back to HTTP/2. Use http2 if outbound UDP is blocked.",
            "auto", "required|string|in:auto,quic,http2"),
        var("Dashboard Username", "DASHBOARD_USERNAME",
            "Username for Studio (HTTP basic auth).",
            "supabase", "required|string|max:64|regex:/^[A-Za-z0-9_.-]+$/"),
        var("Dashboard Password", "DASHBOARD_PASSWORD",
            "Password for Studio. Empty = use the one generated in secrets.env. Needs at least one letter.",
            "", "nullable|string|min:8|max:128"),
        var("Disable Signups", "DISABLE_SIGNUP",
            "Stop new users from signing up to your application.",
            "false", BOOL),
        var("Enable Email Signups", "ENABLE_EMAIL_SIGNUP",
            "Allow email/password signups.",
            "true", BOOL),
        var("Auto-confirm Emails", "ENABLE_EMAIL_AUTOCONFIRM",
            "Skip email confirmation. Turn on if you have not configured SMTP.",
            "false", BOOL),
        var("Allow Anonymous Users", "ENABLE_ANONYMOUS_USERS",
            "Allow anonymous sign-ins.",
            "false", BOOL),
        var("SMTP Host", "SMTP_HOST", "SMTP server for auth emails (confirmations, magic links, resets).",
            "", "nullable|string|max:255"),
        var("SMTP Port", "SMTP_PORT", "SMTP port.", "587", "required|integer|between:1,65535"),
        var("SMTP User", "SMTP_USER", "SMTP username.", "", "nullable|string|max:255"),
        var("SMTP Password", "SMTP_PASS", "SMTP password.", "", "nullable|string|max:255"),
        var("SMTP Sender Email", "SMTP_ADMIN_EMAIL", "From address of auth emails.",
            "admin@example.com", "required|email|max:255"),
        var("SMTP Sender Name", "SMTP_SENDER_NAME", "From name of auth emails.",
            "Supabase", "required|string|max:100"),
        var("Enable Realtime", "ENABLE_REALTIME", "Run the Realtime service (about 150 MB of RAM).",
            "true", BOOL),
        var("Enable Storage", "ENABLE_STORAGE", "Run the Storage service, files are kept in storage/.",
            "true", BOOL),
        var("Max Upload Size", "FILE_SIZE_LIMIT", "Storage upload limit in bytes (default 50 MB).",
            "52428800", "required|integer|min:1"),
        var("JWT Expiry", "JWT_EXPIRY", "Access token lifetime in seconds.",
            "3600", "required|integer|between:60,604800"),
        var("Database Port", "DB_PORT",
            "Internal Postgres port. To reach the database from outside, add an allocation to the server and "
            "put its port here (connections require the password from secrets.env).",
            "5432", "required|integer|between:1024,65535"),
    ],
}

out = root / "egg-supabase.json"
out.write_text(json.dumps(egg, indent=4, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
print(f"wrote {out}")
