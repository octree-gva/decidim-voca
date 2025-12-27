---
sidebar_position: 5
slug: /telemetry
title: Telemetry
description: Improve observability on your Decidim
---

# Telemetry

Decidim Voca provides comprehensive observability through metrics and distributed tracing. The telemetry system uses [Yabeda](https://github.com/yabeda-rb/yabeda) for metrics collection and OpenTelemetry for distributed tracing (APM).

## Overview

The telemetry system exposes:

- **Metrics endpoints**: Prometheus-compatible metrics via Yabeda
- **Health endpoints**: Application health checks
- **Puma metrics**: Server metrics on a separate port
- **Distributed traces**: OpenTelemetry traces exported to an OTLP collector

## Metrics and Health Endpoints

The [decidim-telemetry](https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-telemetry) gem uses Yabeda to expose:

- Health and metrics endpoints (Prometheus format)
- Application workload metrics:
  - Comment, proposal and user creation
  - Votes on comments and proposals
  - Overall Decidim activity (active support notifications)
- Infrastructure metrics:
  - Puma workers and threads
  - Ruby on Rails request times
  - Active Job statuses
  - Database connections

### Puma Metrics

Puma metrics are exposed on a **separate port** (configured via `yabeda-puma-plugin`). This allows monitoring the application server without exposing metrics on the main application port.

## Distributed Tracing (APM)

Distributed tracing is configured automatically when OpenTelemetry environment variables are set. Traces are exported via OTLP to an OpenTelemetry collector endpoint.

### Configuration

Tracing configuration is handled in:
- `lib/decidim/voca/engine.rb` - Initializer that sets up OpenTelemetry middleware
- `app/commands/decidim/voca/open_telemetry_configurator.rb` - SDK configuration
- `lib/decidim/voca/open_telemetry/otel_decidim_context.rb` - Decidim-specific span attributes

The system automatically enriches traces with:
- User ID (`enduser.id`)
- Organization ID and slug (`decidim.organization.*`)
- Participatory space information (`decidim.participatory_space.*`)
- Component information (`decidim.component.*`)

### OpenTelemetry Collector

You need to run an **OpenTelemetry Collector** to receive traces. The collector acts as an intermediary that:
- Receives traces via OTLP
- Processes and exports them to your observability backend (Jaeger, Tempo, Datadog, etc.)

Configure your collector to listen for OTLP traces on the endpoint specified by `OTEL_EXPORTER_OTLP_ENDPOINT`.

## Installation

Add the decidim-telemetry gem to your installation:

```bash
bundle add decidim-telemetry --git https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-telemetry --ref v0.0.3
```

Or add it in your Gemfile:

```ruby
# Gemfile
gem "decidim-telemetry", 
  git: "https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-telemetry", 
  tag: "v0.0.3" # check decidim-voca.gemspec to know which version is compatible with your install
```

Once installed, [follow the installation guidances](https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-telemetry).

## Environment Variables

### Metrics (via decidim-telemetry)

Metrics configuration is handled by the decidim-telemetry gem. Refer to its documentation for specific environment variables.

### Distributed Tracing

| Variable | Description | Required |
|----------|-------------|----------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Base OTLP endpoint for the collector (e.g., `http://otel-collector:4318`) | Yes* |
| `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` | Full traces endpoint (overrides base endpoint + `/v1/traces`) | No |
| `OTEL_SERVICE_NAME` | Service name for traces (defaults to `MASTER_ID` or `rails-app`) | No |
| `MASTER_ID` | Service identifier (used as service name if `OTEL_SERVICE_NAME` not set) | No |
| `MASTER_HOST` | Host name for resource attributes (defaults to `MASTER_IP`) | No |
| `MASTER_IP` | IP address for resource attributes | No |

\* Either `OTEL_EXPORTER_OTLP_ENDPOINT` or `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` must be set to enable tracing.

**Example configuration:**

```bash
# Base endpoint (traces will be sent to http://otel-collector:4318/v1/traces)
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318

# Or specify full traces endpoint
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-collector:4318/v1/traces

# Optional: service identification
OTEL_SERVICE_NAME=decidim-production
MASTER_ID=decidim-prod-1
MASTER_IP=10.0.0.5
```

Tracing is automatically enabled when a valid endpoint is configured. The system checks for OpenTelemetry availability and endpoint configuration at startup.

## References

### Metrics
- [Decidim Telemetry gem](https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-telemetry)
- [Yabeda](https://github.com/yabeda-rb/yabeda)
- [Yabeda Puma](https://github.com/yabeda-rb/yabeda-puma-plugin)
- [Yabeda Active Record](https://github.com/yabeda-rb/yabeda-activerecord)
- [Yabeda Active Job](https://github.com/Fullscript/yabeda-activejob)
- [Yabeda Rails](https://github.com/yabeda-rb/yabeda-rails)

### Distributed Tracing
- [OpenTelemetry Ruby](https://opentelemetry.io/docs/instrumentation/ruby/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [OTLP Protocol](https://opentelemetry.io/docs/specs/otlp/)
- [Prometheus Exporter](https://prometheus.io/docs/instrumenting/exporters/)
