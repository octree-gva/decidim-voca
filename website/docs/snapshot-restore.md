# Snapshot Dump and Restore

This guide explains how Voca snapshots work, how to create them, and how to restore them on local or remote environments.

## Overview

Voca snapshots are encrypted archives containing a complete backup of a Decidim instance, including:
- Database dump (PostgreSQL)
- Storage files (ActiveStorage attachments)
- Migration files
- Module version lockfile
- Metadata (organization hosts)

The snapshot system uses a client-server architecture where:
- **Server**: Creates encrypted snapshots and exposes them via HTTP
- **Client**: Downloads and restores snapshots using the `vocasnap` binary

## Architecture (C4 Model)

### System Context

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Server    │────────▶│   Snapshot   │────────▶│   Client    │
│  (Decidim)  │  dump   │   Storage    │  HTTP   │  (Local/    │
│             │         │  (public/)   │         │   Remote)   │
└─────────────┘         └──────────────┘         └─────────────┘
     │                        │                        │
     │                        │                        │
     ▼                        ▼                        ▼
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│ PostgreSQL  │         │   Web        │         │ PostgreSQL  │
│   Server    │         │   Server     │         │   (Local)   │
└─────────────┘         └──────────────┘         └─────────────┘
```

### Infrastructure

The Decidim container must have `pg_dump` and `psql` installed at the same version as the remote PostgreSQL server. This ensures compatibility when dumping and restoring databases.

**Version Compatibility**:
- `pg_dump` version must match or exceed PostgreSQL server version
- `psql` version must match or exceed PostgreSQL server version
- The system validates versions before dump/restore operations

**Installation** (example for Debian/Ubuntu):
```bash
# Detect PostgreSQL server version
# Install matching client version
apt-get update
apt-get install -y postgresql-client-<version>
```

### Implementation Details

#### Dump Encryption

Snapshots are encrypted using **AES-256-CBC**:
- Password-based encryption (user-provided password)
- Key derivation: SHA256 hash of password
- Random IV per encryption
- Encrypted file format: IV (16 bytes) + encrypted data

```ruby
# Encryption process
1. Create tar.gz archive
2. Encrypt archive with AES-256-CBC
3. Store IV at beginning of encrypted file
4. Remove unencrypted archive
```

#### What Gets Dumped

1. **Database dump** (`dump.sql`):
   - Full PostgreSQL dump using `pg_dump`
   - Flags: `--no-owner --no-acl` (portable across users)
   - Includes all tables, data, indexes, constraints

2. **Storage files** (`storage/`):
   - Local storage: copied from `storage/` directory
   - S3 storage: downloaded from S3 and included in snapshot
   - All ActiveStorage attachments

3. **Migration files** (`migrations/`):
   - All files from `db/migrate/`
   - Ensures schema compatibility on restore

4. **Lockfile** (`vocasnap.lockfile`):
   - Decidim module versions from `Gemfile.lock`
   - NPM lockfile content (`package-lock.json`)
   - Used to validate compatibility on restore

5. **Metadata** (`metadata.json`):
   - Organization hosts (for host replacement on restore)
   - JSON format

#### How Dumps Are Exposed

Snapshots are stored in `public/vocasnap/` directory:
- Accessible via HTTP: `https://example.com/vocasnap/snapshot-<uuid>.vocasnap`
- Old snapshots are automatically cleaned up before creating new ones
- Files are served by the web server (Rails static file serving or reverse proxy)

**Security Note**: Ensure proper access controls on `/vocasnap/` path in production.

## Client: vocasnap Binary

The `vocasnap` binary is a Ruby CLI tool accessible via bundle binstub.
To add the binary, run 
```bash
bundle binstub decidim-voca
```

### Installation

The binary is located at `bin/vocasnap` in the Decidim application. It's automatically available when the gem is installed.

### Commands

#### `vocasnap dump`

Creates an encrypted snapshot of the current instance.

```bash
bin/vocasnap dump
```

**Process**:
1. Prompts for encryption password (twice for confirmation)
2. Checks prerequisites (`pg_dump`, `tar`, version compatibility)
3. Dumps database
4. Creates lockfile
5. Collects storage files
6. Copies migrations
7. Creates tar.gz archive
8. Encrypts archive
9. Moves to `public/vocasnap/`
10. Displays download URL

#### `vocasnap restore SNAPSHOT_PATH`

Restores an instance from a snapshot.

```bash
bin/vocasnap restore <snapshot_path>
```

**Arguments**:
- `SNAPSHOT_PATH`: Local file path or HTTP/HTTPS URL

**Process**:
1. Downloads snapshot (if remote)
2. Prompts for decryption password (with retry on failure)
3. Decrypts snapshot
4. Extracts archive
5. Validates lockfile (module versions)
6. Checks prerequisites
7. Prompts for database drop confirmation
8. Restores migrations
9. Drops and recreates database
10. Restores database dump
11. Prompts for host replacement (if metadata contains hosts)
12. Restores storage files
13. Runs migrations
14. Optionally anonymizes data (if test instance)
15. Installs dependencies (`npm install`)
16. Precompiles assets
17. Cleans up temporary files

#### `vocasnap lint`

Checks prerequisites and system compatibility.

```bash
bin/vocasnap lint
```

**Checks**:
- `psql` binary availability
- PostgreSQL version compatibility
- All required binaries present

#### `vocasnap version`

Shows vocasnap version.

```bash
bin/vocasnap version
```

## Examples

### Example: Dump on Server, Restore Locally

**On Server**:

1. Check prerequisites:
```bash
bin/vocasnap lint
```

2. Create snapshot:
```bash
bin/vocasnap dump
# Enter password when prompted
# Output: Download URL: /vocasnap/snapshot-xxx.vocasnap
```

3. Access snapshot via URL:
```
https://example.com/vocasnap/snapshot-xxx.vocasnap
```

**Locally**:

1. Check prerequisites:
```bash
bin/vocasnap lint
```

2. Restore from remote URL:
```bash
bin/vocasnap restore https://example.com/vocasnap/snapshot-xxx.vocasnap
# Enter decryption password
# Enter new host (e.g., localhost:3000) or press Enter
# Is this a test instance? y/N
# Confirm database drop: yes
```

### Example: Restore on Another Server

**Prerequisites**:
- SSH access to server
- Backup of current database (recommended)
- Application in maintenance mode
- Web servers and background jobs stopped

**Steps**:

1. Transfer snapshot to server:
```bash
scp snapshot-xxx.vocasnap user@server:/path/to/destination/
# Or download on server:
wget https://example.com/vocasnap/snapshot-xxx.vocasnap
```

2. SSH into server:
```bash
ssh user@server
cd /path/to/decidim/app
```

3. Check prerequisites:
```bash
bin/vocasnap lint
```

4. Restore:
```bash
bin/vocasnap restore /path/to/snapshot-xxx.vocasnap
# Enter decryption password
# Enter new host: staging.example.com
# Confirm database drop: yes
# Is this a test instance? N
```

5. After restore:
```bash
# Verify database
bundle exec rails db:version

# Test application
# Restart services
# Clear caches
# Remove maintenance mode
```

## Prerequisites

### For Dump

- PostgreSQL with PostGIS extension
- `pg_dump` binary (matching PostgreSQL server version)
- `tar` binary
- Ruby and Rails environment
- Sufficient disk space for database dump and storage

### For Restore

- PostgreSQL with PostGIS extension
- `psql` binary (matching PostgreSQL server version)
- Ruby and Rails environment
- Sufficient disk space for database and storage
- Access to snapshot file (local or remote URL)

## What Happens During Restore

1. Snapshot is downloaded (if remote) and decrypted
2. Archive is extracted
3. Lockfile is validated (checks module versions)
4. `.gitignore` is checked for `*.vocasnap` exclusion
5. Prerequisites are checked (`psql`, version compatibility)
6. Database is dropped and recreated
7. Database dump is restored via `psql`
8. Host references are updated (if new host provided)
9. Storage files are restored
10. Migrations are restored to `db/migrate/`
11. Migrations are run to ensure schema is up to date
12. Data is anonymized (if test instance)
13. Dependencies are installed (`npm install`)
14. Assets are precompiled
15. Temporary files are cleaned up

## Troubleshooting

### Lockfile Validation Fails

If module versions don't match:
- Update your modules to match the snapshot versions
- Check `Gemfile.lock` and `package-lock.json`
- Restore may fail if versions are incompatible

### Database Restore Fails

- Check PostgreSQL is running
- Verify database credentials in `config/database.yml`
- Ensure sufficient disk space
- Check `psql` version matches PostgreSQL server version
- Review error output for specific issues

### Migration Issues

If migrations fail:
```bash
bundle exec rails db:migrate:status
# Resolve conflicts manually
bundle exec rails db:migrate
```

### Host Replacement Issues

If host references aren't updated correctly:
```bash
bundle exec rails console
Decidim::Organization.update_all(host: 'new-host.com')
```

### Version Compatibility

If `pg_dump` or `psql` version mismatch:
- Install matching PostgreSQL client version
- See `vocasnap lint` output for installation hints
- Example (Debian/Ubuntu):
```bash
apt-get update
apt-get install -y postgresql-client-<version>
```

## Production Checklist

Before restoring on production:

- [ ] Backup current database
- [ ] Put application in maintenance mode
- [ ] Stop web servers and background jobs
- [ ] Verify disk space availability
- [ ] Transfer snapshot file to server
- [ ] Run `bin/vocasnap lint` to check prerequisites
- [ ] Run restore command
- [ ] Verify database restore
- [ ] Test application functionality
- [ ] Update environment variables if needed
- [ ] Restart services
- [ ] Clear caches
- [ ] Remove maintenance mode
- [ ] Monitor application logs

