---
layout: post
title: "I Audited the OpenVPN Server I Wrote a Guide For"
description: "Two years after publishing a guide to restricting OpenVPN clients to specific IPs, I audited the server it built. Most of the findings trace back to the guide."
date: 2026-08-16 17:00:00 +0100
author: "Joey Wang"
tags: [openvpn, firewall, iptables, devops, security]
categories: [Engineering]
---

In October 2024 I published [a guide to restricting OpenVPN clients to specific IP addresses](/posts/how-to-configure-openvpn-to-allow-access-to-specific-ips-only/). It described the setup running on my own server: a group of clients that should only reach a fixed list of destinations, enforced with per-client `iptables` rules installed when each client connects.

Last week I audited that server properly for the first time. Twenty-three findings, two of them critical. The restriction those clients were sold had not been enforced on the server side since roughly the day I wrote about it.

Most of the findings trace back to lines in my own guide. Not typos, either. Patterns that look correct, that I published as advice, and that quietly do nothing.

This is the walk-through I wish I'd had.

## 🔧 Append always loses to insert

The guide's client-connect script:

```bash
for IP in $ALLOWED_IPS; do
    iptables -A FORWARD -i tun+ -d $IP -j ACCEPT
done
iptables -A FORWARD -i tun+ -j DROP
```

Read in isolation this is fine: permit the allow-list, drop everything else. The problem is that no rule exists in isolation.

`-A` appends to the bottom of the chain. Anything that uses `-I` puts itself at the top. On my server, a boot-time unit inserted this:

```bash
iptables -I FORWARD 1 -s 10.8.0.0/24 -j ACCEPT
```

A blanket accept for the whole VPN subnet, at position 1. Every packet from every client matched it and stopped there. The per-client `DROP` at the bottom of the chain was never reached — not sometimes, never.

The rules were present. `iptables -S` listed them. They had simply never once been consulted.

**The fix is to stop competing on position.** Put per-client rules in a dedicated chain and jump to it from the top:

```bash
iptables -N OVPN-CLIENTS
iptables -I FORWARD 1 -i tun0 -j OVPN-CLIENTS
# per-client rules go in OVPN-CLIENTS, where nothing appended later can shadow them
```

Inside that chain, use `RETURN` for permitted traffic rather than `ACCEPT`. `ACCEPT` in a user-defined chain terminates traversal of the entire filter table, so permitted traffic would skip every rule below — on a host also running Kubernetes, that means silently bypassing the network-policy chains. `RETURN` rejoins normal processing and changes nothing else.

## 💡 The same bug was in my own example

Further down, the guide offers this:

```bash
# Allow all traffic for other VPN clients
sudo iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.0/24 -j ACCEPT

# Rules for a specific client (10.8.0.5)
sudo iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.5 -d 93.184.216.34 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.5 -j DROP
```

Four lines, in order, in one code block. The first one makes the next three dead code. `10.8.0.5` is inside `10.8.0.0/24`, so it matches the subnet accept and never reaches its own rules.

I wrote that, published it, and then built a server that behaved exactly as written.

The lesson isn't "be careful". It's that **a firewall snippet is not reviewable in isolation** — order is the whole semantics, and a code block shows you rules while hiding the thing that determines whether they run.

## 🔍 The tool that hides the problem

Here is why this survived two years of me occasionally looking at the config.

```bash
$ sudo iptables -S FORWARD
-A FORWARD -s 10.8.0.0/24 -j ACCEPT
-A FORWARD -s 10.8.0.105/32 -d 203.0.113.10/32 -j ACCEPT
-A FORWARD -s 10.8.0.105/32 -j DROP
```

Everything I expected is there. My guide even recommends `iptables -L -v -n` for inspection, which has the same flaw: it shows you rules, and lets you infer that listed means effective.

What you actually need:

```bash
sudo iptables -L FORWARD -n --line-numbers
```

...and then reading **every chain it jumps to**. The interaction between rules is the only thing that matters, and it is precisely what the default output does not show.

I proved this to myself the hard way during the audit. My first pass reported that VPN clients could reach the Kubernetes API on `6443`, because `ss -tlnp` showed it bound to the wildcard. Reading the chain properly showed a jump to a `K3S-INPUT` chain several rules earlier that dropped exactly that traffic. The finding was wrong. The control plane had been covered all along.

**Reachability is never a bind-address question. It is a packet-filter question, and the filter has to be read as a program, not a list.**

## 🧹 Rules that are added but never removed

My guide's script adds rules on connect. It says nothing about removing them, because I never thought about the other half.

OpenVPN's `learn-address` script gets called with `(action, address, common_name)` — but the common name is only supplied on `add`. On `delete` it is empty:

```
[11:17:58] action=add,    addr=10.8.0.251, cn=test
[11:20:30] action=delete, addr=10.8.0.251, cn=
```

My teardown logic did what most people's does: rebuild the rule list from the client's config file, then delete each entry. With an empty CN, it could not find the config file, so it fell through to a generic branch that removed one rule and left the rest.

For a client with an allow-list of a dozen destinations, that means a dozen `ACCEPT` rules left behind on every single disconnect. They accumulate. They are keyed by VPN IP. And VPN IPs get reassigned to different clients.

**Delete by the one argument you are always given.** Purge every rule whose source matches the disconnecting address, regardless of what the config file says:

```bash
while num=$(iptables -L OVPN-CLIENTS -n --line-numbers \
             | awk -v a="$addr" 'NR>2 && ($5 == a || $5 == a"/32") {print $1; exit}'); \
      [ -n "$num" ]; do
    iptables -D OVPN-CLIENTS "$num"
done
```

This needs no CN, cannot drift out of sync with the config, and clears anything leaked by earlier sessions as a side effect.

One caution when testing this: after you kill a client, its rules survive for as long as the server takes to notice. With `keepalive 10 120` that is up to two and a half minutes. I checked at two minutes flat, concluded the rules had leaked, and said so — they were gone thirty seconds later. **Do not diagnose a cleanup bug inside your own keepalive window.**

## 📊 A monitoring tool inherits its blind spots

I have a small health-check script for this server. It reads easy-rsa's `index.txt` and warns about certificates nearing expiry, revocations missing from the CRL, and stale index bookkeeping. It had been reporting a clean bill of health.

While checking something unrelated, I compared two dates:

- The CA expires **2033-01-19**.
- Seven client certificates are dated **2036-05-28**.

A certificate chain stops validating when its issuer expires. Those three extra years do not exist. More importantly, the CA is self-signed, so it never appears in `index.txt` — and every check in my tool was built from `index.txt`.

**The one certificate whose expiry takes down every client simultaneously was the only one nothing was watching.** Client certificates fail one at a time with 30 days' notice. The CA fails all of them at once, silently, and takes CRL verification with it.

The check I added warns a **year** ahead rather than a month, because renewing a CA means reissuing and redistributing every client profile. Thirty days' notice would arrive far too late to be useful.

The general form is worth keeping: **ask what your monitoring's data source does not contain.** Mine derived everything from one file, so anything absent from that file was invisible — and what was absent turned out to be the single most important date in the PKI.

## ⚠️ My grep was wrong in both directions

Twice during this audit I reached a confident conclusion from a `grep` that was quietly lying.

First, I checked whether client configs used `route-nopull`:

```bash
grep -c '^route-nopull' /etc/openvpn/ccd/*     # 0 everywhere
```

Zero matches. I wrote up that the documentation was wrong about the mechanism. It wasn't — the directive is *pushed*, not set:

```
push "route-nopull"
```

My anchor excluded every real hit. And because anchoring is the normal way to skip commented-out lines, the failure looked exactly like a clean negative result.

Then I over-corrected, dropped the anchor, and matched a set of `#push` lines that were commented out — producing a destination list wider than what was actually routed.

**A `grep` returning zero across a directory that clearly implements the thing you are grepping for is not evidence. It is a broken pattern.** Widen it before you believe the count.

## 💣 The backup that becomes a time bomb

My guide recommends this, as most guides do:

```bash
sudo iptables-save > /tmp/iptables.rules
sudo iptables-restore < /tmp/iptables.rules
```

On the audited server, `iptables-persistent` was installed and **enabled**, holding an 870-rule snapshot from two years ago. That snapshot contained the blanket subnet accept, a per-client lockdown hardcoded to an IP that now belongs to nobody in particular, and a NAT rule that had been dead for a year.

It had never fired, because the unit had been failing at boot — which is also how I knew nothing depended on it, since the host had run fine for a week that way.

Had it ever started successfully, it would have silently reverted the two fixes I had just finished making.

A host can have rules that come from scripts, from units, and from saved snapshots. **The snapshot is the most dangerous of the three: invisible while broken, and catastrophic when repaired.** If your rules are generated by scripts, do not also persist a copy of their output.

## 🎯 What actually went wrong

Every one of these bugs reported success.

The rules were listed. The scripts exited zero. The health check said the PKI was fine. The config file matched the documentation. Nothing in the system disagreed with anything else — and the enforcement those clients were paying for had never once run.

Three habits came out of it that I did not have before:

**Verify the interaction, not the artifact.** A rule that exists, a file that parses, a service that is `active` — none of these tell you the thing runs. For firewalls specifically: `-L --line-numbers` and read every referenced chain.

**Make the failure loud.** When I replaced the blanket accept with an allow-list, I put a rate-limited `LOG` rule immediately above the `DROP`. My allow-list is a guess built from three weeks of thin evidence. If the guess is wrong, it now shows up as a log line rather than as a service that mysteriously stopped working.

**Check what your checks cannot see.** Every tool has a data source, and that source has edges. The bugs live at the edges.

The 2024 guide is still up. It describes a setup that works right up until something else on the host inserts a rule — which, on any machine also running Docker or Kubernetes, is guaranteed. I would rather leave it standing next to this than quietly edit it, because the gap between the two is the actual lesson.

Writing something down does not make it true. Two years of it running without complaint does not either.
