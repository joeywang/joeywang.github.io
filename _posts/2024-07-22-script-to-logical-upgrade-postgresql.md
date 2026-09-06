---
layout: post
title: "Zero-Downtime PostgreSQL Upgrades With Logical Replication"
description: "A bash script that sets up PostgreSQL logical replication, publications, and subscriptions to perform a major-version upgrade without downtime."
date: 2024-07-22 00:00 +0000
pin: true
categories: [Database]
tags: [postgresql, database, devops, automation]
---

<audio controls preload="metadata" src="/assets/audio/script-to-logical-upgrade-postgresql-summary.ogg">
  Your browser does not support the audio element.
</audio>

A PostgreSQL major-version upgrade usually means downtime: dump, restore, and hope the maintenance window is long enough. Logical replication gives you another path. Stand up the new version as a replica, let it catch up, then cut over. Here is the script I use to wire that up.

## How it fits together

The script exports the database list from the source instance, checks whether the schema already exists on the target, and if not dumps the global objects and schema separately and imports them. Then, for each database, it creates a publication on the source covering all tables, and a matching subscription on the target that connects back to the source and starts replicating.

## The script

```bash
#!/bin/bash
set -eo pipefail

# Export schema
export SRC_HOST=postgresql15.db
export DIR=/tmp

# Get databases to sync
get_databases() {
  databases=$(psql -t -h $SRC_HOST -c "select datname from pg_database where not datistemplate and datname<>'postgres' order by datname")
}

import_schema() {
  # Check if more than 3 databases exist to avoid unnecessary dumps
  result=$(psql -t -A -c 'select count(*) > 3 from pg_database')
  if [[ "$result" == "t" ]]; then
    echo "The databases exist."
  else
    echo "The table does not exist."
    # Dump global objects and schema separately
    pg_dumpall -U postgres -g -h $SRC_HOST > $DIR/globals_only.sql
    pg_dumpall -U postgres -s -h $SRC_HOST > $DIR/schema_only.sql
    # Import the dumped files into the 'postgres' database
    psql -U postgres -d postgres -f $DIR/globals_only.sql
    psql -U postgres -d postgres -f $DIR/schema_only.sql
  fi
}

create_publication() {
  # Create publication for all tables in each database
  for db in $databases; do
    # Check if publication already exists
    result=$(psql -t -A -h $SRC_HOST -d $db -c 'select count(*)>0 from pg_publication')
    if [[ "$result" == "f" ]]; then
      psql -h $SRC_HOST -d $db -c 'CREATE PUBLICATION p_upgrade FOR ALL TABLES;'
    fi
  done
}

create_subscription() {
  # Create subscription on replica using the primary's publication
  PASSWORD=${PGPASSWORD/\'/\'\'}
  for db in $databases; do
    sub=${db/-/_}
    sub="s_upgrade_$sub"
    # Check if subscription already exists
    result=$(psql -t -A -c "select count(*)>0 from pg_publication where name='${sub}'")
    if [[ "$result" == "f" ]]; then
      # Construct connection string and create subscription
      connection="host=${SRC_HOST} port=5432 user=postgres password=$PASSWORD dbname=${db}"
      psql -d $db -c "CREATE SUBSCRIPTION $sub CONNECTION '$connection' PUBLICATION p_upgrade;"
    fi
  done
}
```

## What to watch for

`set -eo pipefail` makes the script exit on the first failed command, which is what you want here: a partial replication setup is worse than none. The `PGPASSWORD` handling strips single quotes before building the connection string, that's string escaping, not real credential security, so pull the password from a secrets manager rather than an environment variable in anything resembling production. Run it against staging first, and once replication is running, watch replication lag before you cut traffic over.

## The principle

Logical replication turns a major-version upgrade from a scheduled outage into a cutover you control. This script is a starting point, not a drop-in: adapt the publication and subscription naming to your own conventions, and don't run it against anything real without a tested rollback path and a recent backup.
