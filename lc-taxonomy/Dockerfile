####################################################################
# Dockerfile for creating a Local Cosmos taxonomy database
# - Local Cosmos taxonomy databases are read only 
####################################################################

FROM postgres:16

COPY ["data/1-taxonomy_data.sql.gz", "/docker-entrypoint-initdb.d/"]