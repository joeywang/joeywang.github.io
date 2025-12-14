---
layout: post
title:  "PostgreSQL Setup on Ubuntu: Installation, User Setup, and Real-world Debugging"
date:   2025-11-10 10:00:00 +0000
categories: PostgreSQL
---

# PostgreSQL Setup on Ubuntu: Installation, User Setup, and Real‑World Debugging

This article walks through **installing the latest PostgreSQL on Ubuntu**, **setting up users correctly for development**, and **debugging common authentication failures**, using a real Rails + PostgreSQL example.

It’s written for developers who want to understand *why* things fail, not just copy commands.

---

## 1. Installing the Latest PostgreSQL on Ubuntu (PGDG Repo)

Ubuntu’s default repositories often lag behind PostgreSQL releases. For development (and often production), you should use the **official PostgreSQL Global Development Group (PGDG)** repository.

### 1.1 Add the PostgreSQL APT repository

```bash
sudo apt update
sudo apt install -y wget ca-certificates

wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc \
| sudo tee /usr/share/keyrings/postgresql.asc > /dev/null

echo "deb [signed-by=/usr/share/keyrings/postgresql.asc] \
http://apt.postgresql.org/pub/repos/apt \
$(lsb_release -cs)-pgdg main" \
| sudo tee /etc/apt/sources.list.d/postgresql.list
```

### 1.2 Install PostgreSQL

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
```

Verify:

```bash
psql --version
sudo systemctl status postgresql
```

At this point PostgreSQL is running and has created a **system user and database role** named `postgres`.

---

## 2. Understanding PostgreSQL Authentication (Critical)

Before creating users, it’s essential to understand **how PostgreSQL authenticates**:

| Connection Type | Example     | Auth Rules Used |
| --------------- | ----------- | --------------- |
| Local socket    | `psql`      | `local` rules   |
| TCP localhost   | `127.0.0.1` | `host` rules    |
| TCP network     | remote IP   | `host` rules    |

**Important:**

* `peer` authentication only works over **local sockets**
* Using `host: 127.0.0.1` **forces password authentication**

Most Rails auth issues come from misunderstanding this.

---

## 3. Creating a Development User (Matching Linux User)

Assume your Linux user is:

```bash
whoami
# ubuntu
```

### 3.1 Create a matching PostgreSQL role

```bash
sudo -u postgres createuser ubuntu
```

### 3.2 Set a password (required for TCP connections)

```bash
sudo -u postgres psql -c "ALTER USER ubuntu WITH LOGIN PASSWORD 'devpassword';"
```

### 3.3 Allow database creation (recommended for dev)

```bash
sudo -u postgres psql -c "ALTER USER ubuntu CREATEDB;"
```

### 3.4 (Optional) Create a default database

```bash
sudo -u postgres createdb ubuntu
```

---

## 4. PostgreSQL Authentication Configuration (pg_hba.conf)

PostgreSQL access is controlled by **pg_hba.conf**.

### 4.1 Locate the active file

```bash
sudo -u postgres psql -c "SHOW hba_file;"
```

Edit it:

```bash
sudo nano /etc/postgresql/*/main/pg_hba.conf
```

### 4.2 Recommended dev configuration (TCP localhost)

For Rails using `127.0.0.1`:

```text
host    all     ubuntu     127.0.0.1/32     scram-sha-256
```

Check encryption method:

```bash
sudo -u postgres psql -c "SHOW password_encryption;"
```

Reload (no restart needed):

```bash
sudo systemctl reload postgresql
```

---

## 5. Verifying PostgreSQL Auth *Before* Rails

Always test Postgres directly first.

```bash
psql -U ubuntu -h 127.0.0.1 -d postgres
```

If this fails:

* The password is wrong
* The `pg_hba.conf` rule doesn’t match
* The role doesn’t exist

Do **not** debug Rails until this succeeds.

---

## 6. Rails Configuration (database.yml)

A minimal, explicit development config:

```yml
development:
  adapter: postgresql
  encoding: unicode
  database: cms_dev
  username: ubuntu
  password: devpassword
  host: 127.0.0.1
  port: 5432
```

Create and setup:

```bash
bin/rails db:setup
```

---

## 7. Common Rails + PostgreSQL Failure: Password Authentication Failed

Error:

```text
FATAL:  password authentication failed for user "ubuntu"
```

### Root causes (in order of likelihood)

1. **Rails password ≠ PostgreSQL role password**
2. `DATABASE_URL` overriding `database.yml`
3. Wrong `pg_hba.conf` rule order
4. Using `peer` auth with `127.0.0.1`

### Debug checklist

```bash
echo $DATABASE_URL

sudo -u postgres psql -c "\\du+ ubuntu"

psql -U ubuntu -h 127.0.0.1 -d postgres
```

Fix Postgres first, Rails second.

---

## 8. Optional: Passwordless Local Development (Peer Auth)

If you prefer zero passwords **and no TCP**:

### pg_hba.conf

```text
local   all   ubuntu   peer
```

### Rails config (remove host)

```yml
development:
  adapter: postgresql
  database: cms_dev
  username: ubuntu
```

Now:

```bash
bin/rails db:setup
```

---

## 9. Unrelated but Common Warning: image_processing Gem

Rails warning:

```text
Generating image variants require the image_processing gem
```

Fix:

```bash
bundle add image_processing --version "~> 1.2"
bundle install
```

---

## 10. Mental Model to Remember

* **Postgres auth ≠ MySQL auth**
* `127.0.0.1` → password auth
* socket → peer auth
* Test with `psql` first
* Never debug Rails before Postgres

---

## Conclusion

Most PostgreSQL setup issues on Ubuntu are not installation problems — they are **authentication model misunderstandings**.

Once you internalize how `pg_hba.conf`, connection types, and Rails configs interact, PostgreSQL becomes predictable, secure, and pleasant to work with.

Happy hacking 🚀

