---
layout: post
title: common commands for MySQL
date: 2024-08-23 00:00 +0000
---

```sql
-- Show databases
SHOW DATABASES;

-- Connect to one database
USE database;

-- List tables
SHOW TABLES;

-- Describe table
DESCRIBE users;
-- List user
SELECT * FROM mysql.user;

-- Create user in MySQL/MariaDB.
CREATE USER 'user'@'host' IDENTIFIED BY 'mypassword';
-- Create user access from localhost
CREATE USER 'user'@'localhost' IDENTIFIED BY 'mypassword';
-- user from any host
CREATE USER 'user'@'%' IDENTIFIED BY 'mypassword';

-- Drop user
CREATE USER 'user'@'host';

-- Create a database
CREATE DATABASE IF NOT EXISTS mydb;

-- Grant permissions
GRANT ALL ON database.table TO 'user'@'host';
GRANT ALL ON database.* TO 'user'@'host';

-- Grant permission global
GRANT ALL ON *.* TO 'user'@'host';

-- Show current user permissions
SHOW GRANTS FOR 'user'@'host'
```
