Voca CLI

CLI for technical and secure management of Decidim instances.
Focused on automation, traceability, encryption, and clean DX.

Last updated: 2024-07-19
📦 Authentication

voca login --s3-key <key> --s3-secret <secret> --platform <slug>

Authenticates to the S3 bucket and sets the current platform in ~/.voca/config.yml.
📸 Snapshots

voca snapshot create [--suffix <text>]

Creates a full snapshot (DB + uploads + env) and uploads it to the bucket.

voca snapshot restore <file> --force [--anon] [--host <url>]

Restores a snapshot. ⚠️ Destructive.
--anon: anonymizes sensitive data
--host: rewrites platform domain
--force: mandatory flag

voca snapshot list

Lists all snapshots in the bucket (JSONL, newest first).
No filters or limits.
🚧 Maintenance

voca maintenance on --duration <time>

Creates public/maintenance.html with a message based on duration (e.g. 30m, 2h).
Saves a log at: logs/maintenance-<timestamp>.json

voca maintenance off

Disables maintenance mode and updates the log with ended_at.
🔐 Interventions

voca console

Opens a Rails console and logs the session in .voca format.
Before launching, prompts for:

    Organization (with interactive selection)

    Operator identity

voca intervention

Opens an editor to manually log an intervention.

voca intervention list [--download]

Lists available interventions from the bucket.
If --download, saves them to public/ and generates a magic link.

voca intervention get --id <id> [--download]

Displays the content of an intervention.
If --download, saves it to public/.

voca clean

Removes all downloaded files from the public/ folder.
📤 Report

voca report --org <org_id> [--email <email>]

Generates a technical diagnostic report (DB, S3, configs, logs, versions).
If --email is provided, sends it via SMTP configured in the platform.
If not, displays the email body in the terminal.
🚀 Deploy

voca deploy --snapshot <name>

Uses the Jelastic API to provision new infrastructure and restore from a snapshot.
🔑 Security

All sensitive files uploaded to the bucket are encrypted using the platform's secret_key_base.

voca rotate-secret

Re-encrypts all files using a new secret_key_base.
📄 .voca format

A flat, auditable file format with lines like:

x <timestamp> <input>
x -> <timestamp> <output> +console
x -> <timestamp> <sql> +sql

Example:

x 2025-07-18T14:30:01Z Decidim::User.find_by nickname: "pedro"
x -> 2025-07-18T14:30:02Z => <Decidim::User id=12> +console
x -> 2025-07-18T14:30:05Z UPDATE decidim_users SET ... +sql

🧼 Best Practices

    Never edit .voca logs after a recorded session

    Use voca intervention for manual actions

    Always use voca console for Rails access