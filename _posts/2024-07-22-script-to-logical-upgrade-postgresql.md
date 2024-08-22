---
layout: post
title: "Seamless Logical Upgrades of PostgreSQL with Zero Downtime"
date: 2024-07-22 00:00 +0000
pin: true
categories: PostgreSQL
---

# Seamless Logical Upgrades of PostgreSQL with Zero Downtime

In the world of database management, ensuring zero downtime during upgrades is crucial for maintaining the availability and integrity of services. Logical replication in PostgreSQL provides a powerful mechanism for achieving this. In this article, we will explore a script designed to perform a logical upgrade of PostgreSQL with zero downtime.

## Introduction to Logical Replication

PostgreSQL's logical replication allows you to replicate data changes from one database to another without affecting the primary database's performance. This feature is particularly useful for performing upgrades without downtime, as it enables you to promote a standby database to a primary role once the upgrade is complete.

## The Script: Overview and Components

The provided script is a Bash script designed to automate the process of setting up logical replication for a zero-downtime PostgreSQL upgrade. Let's break down its components:

1. **Environment Setup**: The script starts by setting up the environment with the necessary variables for the source host and the directory to store temporary files.

2. **Database Export**: It defines a function to export the list of databases from the source PostgreSQL instance.

3. **Schema Import Check**: The script checks if the necessary databases exist on the target instance. If not, it proceeds to dump the global objects and schema and import them into the target instance.

4. **Publication Creation**: The script creates a publication for all tables in each database on the primary server. This publication will be used by the subscription on the replica.

5. **Subscription Creation**: For each database, the script creates a subscription on the replica server that connects back to the primary server, using the publication created earlier.

## Detailed Script Analysis

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

### Key Points to Consider

- **Error Handling**: The script uses `set -eo pipefail` to ensure that it exits immediately if a command exits with a non-zero status.
- **Security**: It's important to handle the `PGPASSWORD` securely, especially in production environments. The script attempts to sanitize the password by removing single quotes, but consider more robust security practices.
- **Testing**: Before running this script in a production environment, thoroughly test it in a staging environment to ensure it behaves as expected.
- **Monitoring**: After setting up the replication, continuously monitor the replica to ensure that the data is being replicated correctly and that there are no replication lags.

## Conclusion

Logical replication in PostgreSQL offers a robust solution for performing database upgrades with minimal to no downtime. The provided script is a starting point for automating this process, but it's essential to adapt and expand upon it to suit the specific needs and configurations of your PostgreSQL environment. Always ensure that you have proper backup and recovery strategies in place before performing any upgrade operations.

