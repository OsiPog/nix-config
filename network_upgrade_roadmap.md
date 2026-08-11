# Network upgrade roadmap

High-level roadmap for the network overhaul. These are the **abstract feature steps** — the
concrete, code-level work to finish the ports interface (a prerequisite for all of this) is tracked
separately as the active task.

Domain: `axelhax.net`. Hosts: **haunt-muskie** (VPS, public IP, tailnet `100.64.0.1`),
**floating-trees** (home server, tailnet `100.64.0.4`, LAN `10.12.21.41`).

## Prerequisite — finish the ports interface refactor

The `refactor/network-ports` branch does not currently evaluate. Everything below builds on the
per-port `getAddress` / `reverseProxy` interface, so this must be finished and green first. Tracked
as the active concrete task.

## Step 1 — Centralize the reverse proxy

Move TLS termination + virtual-host routing off the VPS and onto floating-trees; demote haunt-muskie
to a public TCP/SNI stream edge.

```
internet → https://auth.axelhax.net
         → haunt-muskie:443    (nginx stream, ssl_preread/SNI passthrough, NO TLS termination)
         → floating-trees:443  (nginx, terminates TLS + virtual-host)
         → floating-trees:9091 (authelia)
```

- floating-trees = **central terminating proxy** for *every* domain; reaches each backend over the
  tailnet via `getAddress` (incl. `vpn.axelhax.net` → hairpin back to haunt-muskie's headscale).
- haunt-muskie = **`edge = true`** stream proxy. It forwards **all** public ports to their backend
  host:port, not just web — plain TCP passthrough, no TLS work on the edge:
  - **443/80** (NEW) — previously terminated on haunt-muskie; now a **dumb TCP passthrough** to
    floating-trees:443 / :80. SSL is terminated entirely by floating-trees. No `ssl_preread`/SNI
    parsing needed because everything goes to one backend:
    ```nginx
    stream {
      server { listen 443; proxy_pass floating-trees:443; proxy_protocol on; }
      server { listen 80;  proxy_pass floating-trees:80;  proxy_protocol on; }
    }
    ```
  - **All other stream ports** (game servers e.g. `25565`, `ldaps`, …) — forwarded to their backend
    host:port, e.g. `internet → axelhax.net:25565 → haunt-muskie:25565 → floating-trees:25565`.
    This already works via the current stream mechanism (`reverseProxy.nix` `streamConfig`,
    `relevantStreamPorts`); centralization just adds 443/80 into the same treatment.
- **Mail stays terminating on haunt-muskie** (MX needs the public IP) — not forwarded.
- **Keeping hidden services private with a dumb passthrough:** use **PROXY protocol** on the 443/80
  streams so floating-trees sees the *real* client IP (`listen 443 ssl proxy_protocol;` +
  `set_real_ip_from <haunt-muskie>`), and enforce `allow tailnet; allow 10.12.21.0/24; deny all;` on
  hidden virtual-hosts there. Public client → denied; LAN/tailnet → allowed. Raw (non-TLS) hidden
  stream ports keep their edge-side gating as today (`reverseProxy.nix:148-154`).
- Reverse proxy gains a `provide` output exposing what the edge must stream (443/80 + the domains it
  serves, derived from the ports, **plus the non-mail stream ports**); the edge `require`s it and
  builds the nginx `stream` blocks.
- Hidden services on floating-trees gated by **allow tailnet + allow `10.12.21.0/24`, deny all**
  (this is the home-LAN allowlist).

## Step 2 — Split-horizon DNS via a single AdGuard Home on floating-trees

Replace dnsmasq with one declarative AdGuard Home instance on floating-trees (`mutableSettings =
false`; web dashboard for stats + easy blocking; OISD blocklist via `filters`).

- Split-horizon done inside the single instance with **client-scoped rewrite rules**:
  ```
  ||<domain>^$dnsrewrite=NOERROR;A;100.64.0.4,client=100.64.0.0/10   # tailnet → floating-trees tailnet IP
  ||<domain>^$dnsrewrite=NOERROR;A;10.12.21.41,client=10.12.21.0/24  # LAN     → floating-trees LAN IP
  ```
  Both point at floating-trees (it terminates everything). Rules generated in Nix from the
  terminating proxy's served domains + its two IPs (`vpn.ip`, `ipAddress`).
- Public internet uses Porkbun public DNS → haunt-muskie public IP → stream edge.
- Bind DNS to LAN + tailnet only (never `0.0.0.0`) so the VPS/home box is not an open resolver.
- Headscale `dns.nameservers.global = ["100.64.0.4" "1.1.1.1"]` (floating-trees + public fallback).
- Extract the base AdGuard settings + blocklist into a shared `modules/` module; keep the
  network-wiring (provide `dns-server`, generate rewrites from `dns-overrides`) in the network module.

## Step 3 — Router

Point the home router's primary DNS at `10.12.21.41`. Decide the secondary-DNS tradeoff (none =
strict filtering; public secondary = resilient but bypasses AdGuard). Router config, out of repo.

## Verification (end state)

- LAN client (Tailscale off): `dig auth.axelhax.net` → `10.12.21.41`; site loads with valid TLS.
- Tailnet client (off-LAN): `dig auth.axelhax.net` → `100.64.0.4`; loads directly.
- Public internet: loads via haunt-muskie:443 stream → floating-trees.
- Hidden domain reachable on LAN/tailnet but **not** publicly.
- `dig @<haunt-muskie-public-ip> example.com` refused (no open resolver).
- Ad domain blocked; AdGuard dashboard shows queries.

## Risks / decisions on record

- **Headscale now depends on floating-trees** (per "terminate everything on floating-trees"). If the
  home box is down, new/re-authing devices can't reach the control plane (existing links stay up).
  Escape hatch: SNI-route `vpn.axelhax.net` locally on the haunt-muskie edge.
- **All public web traffic hairpins through the home uplink** (VPS → home). Intended.
- **Single home resolver** = DNS SPOF; mitigated by the Headscale fallback + optional router
  secondary DNS.
