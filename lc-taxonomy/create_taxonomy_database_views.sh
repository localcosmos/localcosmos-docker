#!/bin/bash

##################################################################################################
#
# Script for creating postgresql materialized view of taxonomic databases
# - creates the taxonnames_view
# - usage example: bash create_taxonomy_database_views.sh  -dbuser=DBUSER -dbpassword=DBPASSWORD -schema=public -db=taxonomy -taxondb=col
#
##################################################################################################


for i in "$@"
do
case $i in
	-dbuser=*)
	dbuser="${i#*=}"
	shift # past argument=value
	;;
	-dbpassword=*)
	dbpassword="${i#*=}"
	shift # past argument=value
	;;
	-schema=*)
	schema="${i#*=}"
	shift # past argument=value
	;;
	-db=*)
	database="${i#*=}"
	shift # past argument=value
	;;
	-taxondb=*)
	taxon_database="${i#*=}"
	shift # past argument=value
	;;
	*)
	  # unknown option
	;;
esac
done


echo "creating views for database ${taxon_database} schema ${schema}"

drop_sql="DROP MATERIALIZED VIEW IF EXISTS ${schema}.${taxon_database}_${taxon_database}taxonnamesview"
echo $drop_sql

create_sql="CREATE MATERIALIZED VIEW ${schema}.${taxon_database}_${taxon_database}taxonnamesview \
AS SELECT t.name_uuid, t.taxon_nuid, t.taxon_latname, t.taxon_author, t.taxon_latname AS name,  t.rank, 'la' AS language, 'accepted name' AS name_type, TRUE AS preferred \
FROM ${schema}.${taxon_database}_${taxon_database}taxontree t \
UNION \
SELECT s.name_uuid, t.taxon_nuid, t.taxon_latname, s.taxon_author, s.taxon_latname AS name, t.rank, 'la' AS language, 'synonym' AS name_type, FALSE AS preferred  \
FROM ${schema}.${taxon_database}_${taxon_database}taxonsynonym s \
LEFT JOIN ${schema}.${taxon_database}_${taxon_database}taxontree t ON (s.taxon_id = t.name_uuid)
UNION
SELECT v.name_uuid, t.taxon_nuid, t.taxon_latname, t.taxon_author, v.name AS name, t.rank, v.language AS language, 'vernacular' AS name_type, v.preferred AS preferred
FROM ${schema}.${taxon_database}_${taxon_database}taxonlocale v \
LEFT JOIN ${schema}.${taxon_database}_${taxon_database}taxontree t ON (v.taxon_id = t.name_uuid)"

echo $create_sql


export PGPASSWORD=${dbpassword}
psql -U ${dbuser} -h localhost -d ${database} -c "${drop_sql}"
psql -U ${dbuser} -h localhost -d ${database} -c "${create_sql}"

# GRANT
grant_select_sql="GRANT SELECT ON ${taxon_database}_${taxon_database}taxonnamesview TO ${dbuser};"
psql -U ${dbuser} -h localhost -d ${database} -c "${grant_select_sql}"

# name upper index
name_upper_index_name="${taxon_database}_${taxon_database}taxonnamesview_name_upper_idx"
drop_name_upper_index_sql="DROP INDEX IF EXISTS ${schema}.${name_upper_index_name}"

create_name_upper_index_sql="CREATE INDEX ${name_upper_index_name} \
ON ${schema}.${taxon_database}_${taxon_database}taxonnamesview \
USING btree \
(upper(name::text) COLLATE pg_catalog."default" varchar_pattern_ops);"

psql -U ${dbuser} -h localhost -d ${database} -c "${drop_name_upper_index_sql}"
psql -U ${dbuser} -h localhost -d ${database} -c "${create_name_upper_index_sql}"

# compound search index
name_type_nuid_name_index_name="${taxon_database}_${taxon_database}taxonnamesview_name_type_taxon_nuid_name_upper_idx"
drop_name_type_nuid_name_index_sql="DROP INDEX IF EXISTS ${schema}.${name_type_nuid_name_index_name}"

create_name_type_nuid_name_index_sql="CREATE INDEX ${name_type_nuid_name_index_name} \
ON ${schema}.${taxon_database}_${taxon_database}taxonnamesview \
USING btree \
(name_type COLLATE pg_catalog."default", taxon_nuid COLLATE pg_catalog."default", upper(name::text) \
COLLATE pg_catalog."default" varchar_pattern_ops);"

psql -U ${dbuser} -h localhost -d ${database} -c "${drop_name_type_nuid_name_index_sql}"
psql -U ${dbuser} -h localhost -d ${database} -c "${create_name_type_nuid_name_index_sql}"

# pseudo pk index
name_uuid_index_name="${taxon_database}_${taxon_database}taxonnamesview_name_uuid_idx"
drop_name_uuid_index_sql="DROP INDEX IF EXISTS ${schema}.${name_uuid_index_name}"

create_name_uuid_index_sql="CREATE UNIQUE INDEX ${name_uuid_index_name} \
ON ${schema}.${taxon_database}_${taxon_database}taxonnamesview \
USING btree (name_uuid ASC NULLS LAST) TABLESPACE pg_default;"


psql -U ${dbuser} -h localhost -d ${database} -c "${drop_name_uuid_index_sql}"
psql -U ${dbuser} -h localhost -d ${database} -c "${create_name_uuid_index_sql}"
