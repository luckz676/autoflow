# frozen_string_literal: true
# Puma configuration for AutoFlow (Sinatra + SQLite)
# Optimized for Render free tier (512MB RAM, shared CPU)

environment ENV.fetch("RACK_ENV", "production")

# Workers: 0 for single-process (saves memory, avoids port conflicts on free tier)
workers 0

# Threads: min/max - keep small for SQLite + low memory
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3).to_i
threads threads_count, threads_count

# Port - Render sets PORT env var (typically 10000)
# Bind to all interfaces (required for containers)
bind "tcp://0.0.0.0:#{ENV.fetch("PORT", 10000)}"

# Preload app for memory efficiency
preload_app!

# Worker timeout - generous for SQLite operations
worker_timeout 60

# Pidfile and state
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")
state_path ENV.fetch("STATE_PATH", "tmp/pids/puma.state")

# Silent startup
quiet

# Run garbage collection between requests
on_worker_boot do
  GC.start if defined?(GC)
end

# Health check endpoint support
plugin :tmp_restart