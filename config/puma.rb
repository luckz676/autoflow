# frozen_string_literal: true
# Puma configuration for AutoFlow (Sinatra + SQLite)
# Optimized for Fly.io free tier (256MB RAM, shared CPU)

environment ENV.fetch("RACK_ENV", "production")

# Workers: 0 for single-process (saves memory), threads handle concurrency
workers ENV.fetch("WEB_CONCURRENCY", 0)

# Threads: min/max - keep small for SQLite + low memory
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3).to_i
threads threads_count, threads_count

# Port - Fly.io uses 8080 by default
port ENV.fetch("PORT", 8080)

# Bind to all interfaces (required for containers)
bind "tcp://0.0.0.0:#{ENV.fetch("PORT", 8080)}"

# Preload app for memory efficiency (copy-on-write with workers)
preload_app!

# Worker timeout - generous for SQLite operations
worker_timeout 60

# Restart workers periodically to prevent memory bloat
# max_worker_lifetime 3600 if workers > 0

# Pidfile and state (optional, but useful for debugging)
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")
state_path ENV.fetch("STATE_PATH", "tmp/pids/puma.state")

# Logging
stdout_redirect "log/puma.stdout.log", "log/puma.stderr.log", true if ENV["RACK_ENV"] == "production"

# Silent startup
quiet

# Run garbage collection between requests (helps with memory on small instances)
on_worker_boot do
  GC.start if defined?(GC)
end

# Health check endpoint support
plugin :tmp_restart