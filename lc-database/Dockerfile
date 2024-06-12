####################################################################
# Dockerfile for creating the official Local Cosmos database image
# VERSION: 1.0
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
    apt-get install -y build-essential libpq-dev postgresql-server-dev-$POSTGRESQL_VERSION postgresql-$POSTGRESQL_VERSION-postgis-scripts &&\
    apt-get clean autoclean &&\
    apt-get autoremove -y &&\
    rm -rf /var/lib/{apt,dpkg,cache,log}/

COPY ["kmeans-postgresql-master/", "/opt/kmeans-postgresql-master/"]

WORKDIR /opt/kmeans-postgresql-master
RUN make &&\
	make install

CMD ["postgres"]