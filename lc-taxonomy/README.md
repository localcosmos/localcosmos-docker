# docker-compose for running the taxonomic databases (CoL etc)

Databases containing taxonomic references for Local Cosmos are read only.

## Database creation
IMPORTANT: before dumping, make sure all tables, including materialized views, belong to the owner named "linnaeus"
command to dump taxonomy database:
pg_dump taxonomy > taxonomy.sql
gzip -c taxonomy.sql > taxonomy_data.sql.gz

Manually restore the db (for development):
gunzip -c taxonomy_data.sql.gz | psql {database_name}

## How to build the image
docker build -t  localcosmos/lc-taxonomy .