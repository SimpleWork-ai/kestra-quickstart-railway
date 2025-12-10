#!/usr/bin/env sh
set -e

# If DATABASE_URL is provided in the PostgreSQL style used by Railway
# (postgresql://user:password@host:port/db), convert it to a JDBC URL
# that Kestra/Hikari understand (jdbc:postgresql://host:port/db?user=...&password=...&sslmode=require).
if [ -n "$DATABASE_URL" ]; then
  case "$DATABASE_URL" in
    postgresql://*)
      stripped="${DATABASE_URL#postgresql://}"
      creds="${stripped%%@*}"       # user:password
      rest="${stripped#*@}"         # host:port/db[?params]

      user="${creds%%:*}"
      pass="${creds#*:}"

      host_port_db="${rest%%\?*}"   # drop any existing query for safety

      # Build JDBC URL with user/password as query parameters.
      jdbc="jdbc:postgresql://$host_port_db?user=$user&password=$pass&sslmode=require"
      export DATABASE_URL="$jdbc"
      ;;
    jdbc:postgresql://*)
      # Already in JDBC form; leave as-is.
      ;;
    *)
      # Other schemes – leave untouched.
      ;;
  esac
fi

# Optional: limit worker threads for lower resource usage.
# Example: KESTRA_WORKER_THREADS=32
EXTRA_ARGS=""
if [ -n "$KESTRA_WORKER_THREADS" ]; then
  EXTRA_ARGS="--worker-thread=$KESTRA_WORKER_THREADS"
fi

exec /app/kestra server standalone $EXTRA_ARGS --config /app/config/application.yaml
