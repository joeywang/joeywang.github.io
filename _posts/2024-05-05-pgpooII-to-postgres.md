---
layout: post
title:  "Postgres 'Too Many Connections': Debugging Pgpool-II Limits"
description: "Debugging a Postgres 'too many connections' error through Pgpool-II's num_init_children and max_pool settings, and the fix that stopped clients queueing."
date:   2024-05-05 14:41:26 +0100
categories: [Database]
tags: [postgresql, devops, kubernetes]
---

<audio controls preload="metadata" src="/assets/audio/pgpooII-to-postgres-summary.ogg">
  Your browser does not support the audio element.
</audio>


We've run PostgreSQL in production since 8.3, upgrading all the way to 14 with a zero-downtime migration from 11 to 13. MongoDB was in the mix at one point too, but join-heavy queries pushed us back to Postgres for good.

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

These two settings have to satisfy a relationship or Pgpool-II misbehaves:

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

PostgreSQL handles concurrent load well, but managing a large number of concurrent connections is still a real operational problem. Pgpool-II helps, but only once you understand how `num_init_children`, `max_pool`, and `reserved_connections` interact, because the default behavior queues clients instead of failing fast.

## References

- [Connection Pooling in Pgpool](https://b-peng.blogspot.com/2020/07/connection-pooling-in-pgpool.html)
