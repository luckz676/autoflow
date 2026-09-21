# Dockerfile for AutoFlow (Sinatra + SQLite + Puma)
# Deploy target: Fly.io (free tier with persistent volume)

FROM ruby:3.3-slim

# Install system dependencies for sqlite3 gem and runtime
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    libsqlite3-dev \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Set production environment
ENV RACK_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test"

# Install gems first (better layer caching)
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Create directory for database (will be mounted as volume)
RUN mkdir -p /app/db

# Expose port (Fly.io expects 8080 by default, but we'll configure)
EXPOSE 8080

# Start with Puma on 0.0.0.0:8080
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]