psql -U postgres -f sql/setup/_all.sql postgres
psql -U postgres -f sql/_all.sql $CUSTOM_DB
