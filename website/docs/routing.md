---
sidebar_position: 4
slug: /routing
title: Traefik Routing
description: How to sync Decidim organizations to Traefik via Redis
---

# Traefik Routing

This module synchronizes Decidim organization hosts and subdomains to a Redis database using Traefik's KV store format. This enables dynamic routing configuration for multi-tenant Decidim instances behind a Traefik reverse proxy.

## How It Works

The routing system:

1. **Generates unique identifiers**: Each organization gets a UUID (`voca_external_id`) that is automatically created when the organization is created
2. **Syncs routing rules**: Organization hosts and secondary hosts are synced to Redis in Traefik's KV format
3. **Configures services**: Sets up load balancer configuration with health checks
4. **Supports multiple servers**: Uses unique keys (UUIDs) to avoid conflicts when multiple servers sync routes

## Features

- **Automatic routing sync**: Organizations are automatically synced when created or updated
- **Multi-host support**: Supports both primary host and secondary hosts per organization
- **Health check configuration**: Configures Traefik health checks for service monitoring
- **TLS configuration**: Automatically configures certificate resolvers (skips for localhost domains)
- **Multi-server support**: UUID-based keys prevent conflicts when multiple servers sync routes

## Architecture

### Infrastructure
![Redis routing infrastructure](/c4/images/structurizr-routing-infra.png)  
- **Decidim app servers** push routing keys into Redis (Traefik KV).
- **Traefik nodes** read from the shared Redis instance to build routers and services dynamically.
- **Redis (Traefik KV)** stores routing data centrally, eliminating static file reloads.

### Routing flow
![Route synchronization flow](/c4/images/structurizr-routing-sync-logics.png)  

**Scenario**: Given a Decidim organization A and a Decidim organization B, when organization A is created or updated:
1. The organization emits create/update hooks that enqueue a sync job
2. The job ensures the organization has a UUID (`voca_external_id`)
3. Router/service entries are written to Redis in Traefik format
4. Traefik consumes those keys, generates SSL certificates, and exposes the host

## Usage

### Sync Routes

To sync all organization routes to Redis:

```bash
bundle exec rake decidim:voca:sync_routes
```

This task:
- Iterates through all Decidim organizations
- Ensures each organization has a `voca_external_id`
- Syncs routing configuration to Redis
- Updates common service configuration

### View Routes

To view all registered routes:

```bash
# JSONL format (default): host => service URL
bundle exec rake decidim:voca:routes

# Traefik format: full Traefik configuration
FORMAT=traefik bundle exec rake decidim:voca:routes
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TRAEFIK_REDIS_URL` | Redis connection URL for Traefik KV store | `redis://traefik-db:6379/1` |
| `MASTER_ID` | Service identifier for load balancer | Required |
| `MASTER_IP` | Service URL/IP address | Required |
| `TRAEFIK_SERVICE_PROTOCOL` | Protocol for service URL | `http` |
| `TRAEFIK_SERVICE_PORT` | Port for service URL | `8080` |
| `TRAEFIK_SERVICE_HEALTHCHECK_PATH` | Health check endpoint path | `/health/live` |
| `TRAEFIK_SERVICE_HEALTHCHECK_PORT` | Health check port | `8080` |
| `TRAEFIK_SERVICE_HEALTHCHECK_INTERVAL` | Health check interval | `60s` |
| `TRAEFIK_SERVICE_HEALTHCHECK_TIMEOUT` | Health check timeout | `10s` |
| `TRAEFIK_SERVICE_ENTRYPOINT` | Traefik entrypoint name | `websecure` |
| `TRAEFIK_CERT_RESOLVER` | Certificate resolver name for TLS | `letsencrypt` |

:::info
Virtuozzo/Jelastic environments expose `MASTER_ID` and `MASTER_IP` natively.
**If you don't use Jelastic, set these variables**:
- `MASTER_ID`: a random unique identifier
- `MASTER_IP`: an IP address that the Traefik instance can reach (do not add a public ip for more security)
:::

## Routing Configuration

Each organization creates the following Traefik router configuration:

- **Router rule**: `Host(primary_host) || Host(secondary_host_1) || ...`
- **Entrypoint**: Configured via `TRAEFIK_SERVICE_ENTRYPOINT` (default: `websecure`)
- **Service**: Points to `service-{MASTER_ID}`
- **Priority**: `100`
- **TLS**: Uses configured cert resolver (skipped for `.localhost` domains)

The service configuration includes:
- Load balancer server URL
- Health check path, port, interval, and timeout

## Requirements

- Redis instance accessible to both Decidim and Traefik
- Traefik configured with Redis KV provider
- `MASTER_ID` and `MASTER_IP` environment variables set
- Organizations must have valid host configurations

## References

- [Traefik KV Store Documentation](https://doc.traefik.io/traefik/reference/routing-configuration/other-providers/kv/)
- [Traefik Routing Configuration](https://doc.traefik.io/traefik/routing/routers/)
