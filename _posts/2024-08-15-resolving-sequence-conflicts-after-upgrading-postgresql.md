---
layout: post
title: "PostgreSQL Sequence Conflicts After an Upgrade: How to Fix Them"
description: "Upgrading PostgreSQL can leave sequences out of sync with table max values, causing duplicate-key errors and blocked sign-ins, fixed here with SQL and bash."
date: 2024-08-15 14:01 +0100
categories: [Database]
tags: [postgresql, database, devops]
---
<audio controls preload="metadata" src="/assets/audio/resolving-sequence-conflicts-after-upgrading-postgresql-summary.ogg">
  Your browser does not support the audio element.
</audio>

After upgrading from PostgreSQL 15 to 16, some sequences no longer matched the max value in their table: duplicate-key errors on insert, and in one case, blocked sign-ins. Here's the SQL function and the bash script I used to find and fix every misaligned sequence.

## Why sequences drift after an upgrade

A PostgreSQL sequence is a database object that generates integer values, most often used for primary keys. During a major-version upgrade, sequence state doesn't always carry over in step with the data in the tables it feeds, so a sequence can end up behind the actual max value already in use, and the next insert collides with an existing key.

## A function that resets sequences to match table data

```sql
CREATE OR REPLACE FUNCTION reset_sequences_to_max(schema varchar default 'public', dry_run bool default true)
RETURNS void AS $$
DECLARE
    r RECORD;
    query TEXT;
BEGIN
    -- Loop through all tables
    FOR r IN SELECT t.table_schema, t.table_name, column_name, sequence_name
             FROM information_schema.tables t
             JOIN information_schema.columns c ON t.table_name = c.table_name
             JOIN information_schema.sequences s ON 'nextval('''||s.sequence_name||'''::regclass)' = c.column_default
             WHERE t.table_schema = schema
    LOOP
        -- Construct the dynamic query to set the sequence value
        query := format('SELECT setval(''%I'', (SELECT MAX(%I) FROM %I.%I) - 1);',
                         r.sequence_name, r.column_name, r.table_schema, r.table_name);

        -- Execute the dynamic query
        if dry_run then
            raise notice'Run query: %', query;
        else
            EXECUTE query;
        end if;

    END LOOP;
END;
$$ LANGUAGE plpgsql;
```

It loops through every table in the given schema, builds a `setval` call for each sequence, and either prints the query for review or runs it, depending on `dry_run`.

```sql
SELECT reset_sequences_to_max('public', false); -- set dry_run to false to execute
```

## A bash script for resetting sequences across many databases

For multiple databases at once, generate the `setval` statements directly from the catalog and run them per database:

```bash
cat > /tmp/reset.sql << EOL
-- SQL commands to reset sequences
 SELECT
     'SELECT SETVAL(' ||
        quote_literal(quote_ident(sequence_namespace.nspname) || '.' || quote_ident(class_sequence.relname)) ||
        ', COALESCE(MAX(' ||quote_ident(pg_attribute.attname)|| '), 1) ) FROM ' ||
        quote_ident(table_namespace.nspname)|| '.'||quote_ident(class_table.relname)|| ';'
 FROM pg_depend
     INNER JOIN pg_class AS class_sequence
         ON class_sequence.oid = pg_depend.objid
             AND class_sequence.relkind = 'S'
     INNER JOIN pg_class AS class_table
         ON class_table.oid = pg_depend.refobjid
     INNER JOIN pg_attribute
         ON pg_attribute.attrelid = class_table.oid
             AND pg_depend.refobjsubid = pg_attribute.attnum
     INNER JOIN pg_namespace as table_namespace
         ON table_namespace.oid = class_table.relnamespace
     INNER JOIN pg_namespace AS sequence_namespace
         ON sequence_namespace.oid = class_sequence.relnamespace
 ORDER BY sequence_namespace.nspname, class_sequence.relname;
EOL
```

```bash
for db in $databases; do
    psql -Atq -f /tmp/reset.sql -d $db -o /tmp/$db.sql
    psql -f /tmp/$db.sql -d $db
done
```

## The principle

Back up before running either of these against anything real, and use the function's `dry_run` default to see the generated `setval` statements before you execute them. Sequence drift after an upgrade is common enough to check for by default, not just when sign-ins start failing.
