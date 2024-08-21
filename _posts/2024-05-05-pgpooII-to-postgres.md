---
layout: post
title:  "Too many connections already"
date:   2024-05-05 14:41:26 +0100
categories: PostgreSQL
tags: [postgres, devops]
---

# Too many connectioins: Managing PostgreSQL Connections with Pgpool-II

PostgreSQL is my favorite database, and I have experience with Oracle, SQL Server, MySQL, and MongoDB. However, due to performance issues with MongoDB, especially on join searches, we decided to stick with PostgreSQL. Over the years, we've upgraded from PostgreSQL 8.3 to the latest version, 14, achieving "Zero" downtime migration from version 11 to 13.

## PostgreSQL Connection Limitations

PostgreSQL is known for its limitation on concurrent connections, typically around 100, which can be adjusted in the configuration file:

```ini
/etc/postgresql/13/postgresql.conf
max_connections = 100
shared_buffers = 24MB
```

Alternatively, settings can be changed on-the-fly using the `ALTER SYSTEM` command, which writes to `postgresql.auto.conf`:

```sql
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = 4864MB;
```

For configuration tuning, PGTune is a valuable resource that suggests settings based on your system specifications.

## Introducing Pgpool-II

To handle more than 200 connections, we introduced Pgpool-II. However, we encountered errors that suggested a misconfiguration. The key settings in Pgpool-II are:

```ini
num_init_children
max_pool
```

The relationship between these settings is crucial:

```plaintext
max_pool * num_init_children <= (max_connections - superuser_reserved_connections)
```

After adjusting these settings, we resolved the connection issues.

## Further Challenges

Despite resolving the initial connection errors, we faced new challenges with web performance and `psql` freezing when connecting through Pgpool-II but not directly to PostgreSQL. A careful review of the documentation revealed a misunderstanding of the `num_init_children` setting, which also limits concurrent client connections to Pgpool-II.

## Solutions and Improvements

To address the queueing issue, we set `reserved_connections` to 1, allowing Pgpool-II to behave similarly to PostgreSQL by immediately returning errors to incoming clients rather than holding them in a queue.

We also implemented Horizontal Pod Autoscaler (HPA) to ensure that client connections are not rejected and that the livenessProbe remains successful, preventing unnecessary pod restarts.

## Ongoing Challenges and Strategies

Even with these improvements, the 200 connection limit persists. To overcome this, we are considering the following strategies:

1. **Use a Standby Server**: To share connections for read operations.
2. **Application-Level Connection Pooling**: Ensuring efficient reuse of connections at the application level.
3. **Increase Max Connections**: As a final option, increase the PostgreSQL `max_connections` setting.

## Conclusion

While PostgreSQL offers robust performance and features, managing a large number of concurrent connections can be challenging. Pgpool-II is a valuable tool for connection management, but it requires careful configuration to avoid potential pitfalls. By understanding and addressing these challenges, we can ensure a scalable and reliable database architecture.

## References

- [Connection Pooling in Pgpool](https://b-peng.blogspot.com/2020/07/connection-pooling-in-pgpool.html)
