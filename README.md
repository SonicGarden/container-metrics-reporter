# ContainerMetricsReporter

A Ruby gem that collects container cgroup metrics (memory and CPU) and reports them to Sentry Application Metrics via SolidQueue worker lifecycle hooks.

## Requirements

- Ruby >= 3.3
- Rails + SolidQueue
- Linux cgroup v2 (`/sys/fs/cgroup/`)
- sentry-ruby

## Installation

Add this line to your application's Gemfile:

```ruby
gem "container_metrics_reporter", github: "SonicGarden/container-metrics-reporter", branch: "main"
```

No initializer is required for the default configuration. Simply adding the gem is enough — the Railtie automatically registers the `SolidQueue.on_worker_start/stop` hooks.

## Configuration

You can customize the behavior via an initializer (all values shown are defaults):

```ruby
# config/initializers/container_metrics_reporter.rb
ContainerMetricsReporter.configure do |config|
  config.interval       = 5.minutes      # Collection interval
  config.sleep_tick     = 5              # Interrupt check cycle in seconds
  config.collect_memory = true           # Whether to report memory usage
  config.collect_swap   = true           # Whether to report swap usage
  config.collect_cpu    = true           # Whether to report CPU usage
  config.hostname       = "a3f2b1c4d5e6" # Defaults to $HOSTNAME or the first segment of Socket.gethostname
end
```

## Metrics

Each worker process reports the following gauges to Sentry immediately on startup, then approximately every 5 minutes:

| Metric | Unit | Description |
|---|---|---|
| `container_memory_usage_percent` | percent | Memory usage relative to the cgroup limit |
| `container_swap_usage_percent` | percent | Swap usage relative to the cgroup limit |
| `container_cpu_usage_percent` | percent | CPU usage as a percentage of one core (100% = 1 core fully used, 200% = 2 cores fully used) |

All metrics include a `hostname` attribute.

> [!NOTE]
> Memory and swap metrics require a cgroup memory limit to be configured (e.g. via Docker's `--memory` / `--memory-swap` flags). If no limit is set, the cgroup file contains `"max"` and the metric is silently skipped.

## How It Works

When a SolidQueue worker starts, a background thread is launched that immediately calls `perform`, then loops with an approximately 5-minute wait (approximated via 5-second sleep ticks) after each `perform` completes.

Metrics are read directly from the following cgroup v2 files:

- `/sys/fs/cgroup/memory.current` / `memory.max`
- `/sys/fs/cgroup/memory.swap.current` / `memory.swap.max`
- `/sys/fs/cgroup/cpu.stat`

If a file does not exist (`ENOENT`), that metric is silently skipped.

## Coexistence with Custom Hooks

`SolidQueue.on_worker_start/stop` appends to an array, so this gem does not conflict with your own hooks:

```ruby
# config/initializers/solid_queue.rb
SolidQueue.on_worker_start { MyOtherThing.boot }
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
