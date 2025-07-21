Voca CLI

# Configure account access. Most production server will have one account, and 
# developpers can setup many acount
voca config

# TODO Create a snapshot for all files required in decidim (db/storage)
# storage: if S3 active storage, download all of them in a storage folder and setup a ActiveStorageBlobs mapping (which id in restored file needs to be updated to which local fiçe)
# db: create a migration mapping, to know the hash of migration file that has been selected. (will reset migration information on restore)
# meta: save voca version, decidim version and needed deps (bundler, node, ruby) to check compat before restore
voca snapshot create 
voca snapshot list
voca snapshot restore <file> --force [--anon] [--host <url>]

# TODO Setup maintenance page for the organization and setup a temporary access
# (change nginx config)
# Templates for maintenance.html will depends on duration, and takes: 
#   - organization color
#   - organization logo
voca maintenance on --duration <time> --org orgid --host temp_access_host
voca maintenance off

# TODOSee interventions (created with rails console)
voca intervention
# TODO --download: download intervention txt, and share it (see voca share)
voca intervention list [--download]
voca intervention get --id <id> [--download]


# TODO Create a public file on public/share/<file>-<uuid>
# tar if the share is a folder
voca share file|dir

# TODO Remove share folder
voca clean

# TODO Test integrations and send report by email using smtp org
voca report --org <org_id> [--email <email>] 

# TODO Deploy a new infrastructure on jelastic, and put a copy on it
voca deploy --snapshot <name>

# TODO Loop over all encrypted column and decrypt/re-encrypt data
# TODO Loop over shared bucket .enc files and rotate as well 
voca rotate-secret

# TODO restart the server with `rails restart`
# TODO --hard mode will:
#   - put in maintenance all org of the server with a 5min message
#   - recompile assets
#   - recompile deface
#   - clear cache completly
#   - exec a rails restart
#   - put maintenance off
voca restart --hard
