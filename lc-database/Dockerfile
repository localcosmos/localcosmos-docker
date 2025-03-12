####################################################################
# Dockerfile for creating the official Local Cosmos database image
# - based on postgres:16
# - default database for the Local cosmos django app
# - does not contain the database for taxonomic references
####################################################################

FROM postgres:16

ARG POSTGRESQL_VERSION=16
ARG POSTGIS_VERSION=3

# install postgresql kmeans extension
RUN apt-get update &&\
    apt-get install --no-install-recommends -y postgresql-$POSTGRESQL_VERSION-postgis-$POSTGIS_VERSION &&\
    apt-get install -y build-essential libpq-dev postgresql-server-dev-$POSTGRESQL_VERSION postgresql-$POSTGRESQL_VERSION-postgis-scripts postgresql-contrib &&\
    apt-get clean autoclean &&\
    apt-get autoremove -y &&\
    rm -rf /var/lib/{apt,dpkg,cache,log}/

# Ensure correct PostgreSQL headers are found
ENV PG_CONFIG /usr/lib/postgresql/$POSTGRESQL_VERSION/bin/pg_config
ENV PATH /usr/lib/postgresql/$POSTGRESQL_VERSION/bin:$PATH

COPY ["kmeans-postgresql-master/", "/opt/kmeans-postgresql-master/"]

WORKDIR /opt/kmeans-postgresql-master
RUN make PG_CONFIG=$PG_CONFIG && make install PG_CONFIG=$PG_CONFIG

CMD ["postgres"]