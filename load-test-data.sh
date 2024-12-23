# Loads test data (generally a backup of the live site) from jasb-backup.sql,
# then updates the credentials to the testing ones if they got modified by the
# backup, and finally migrates.

docker compose up -d storage
docker compose cp jasb-backup.sql storage:test-data.sql
docker compose exec storage psql --username="jasb" --dbname="jasb" --file="test-data.sql"
docker compose exec storage psql --username="jasb" --dbname="jasb" --command="ALTER USER jasb PASSWORD 'jasb';"
docker compose --profile migrate run --rm --remove-orphans --build migrate migrate -X
