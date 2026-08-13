#!/usr/bin/env bash
# copilot-token-usage.sh
#
# Reports GitHub Copilot CLI token usage (input, output, cache read/write)
# grouped by day, plus a summary average, sourced from the local
# assistant_usage_events table in ~/.copilot/session-store.db.
#
# Usage:
#   ./copilot-token-usage.sh [DAYS]
#
# DAYS defaults to 30 if not provided.

set -euo pipefail

DAYS="${1:-30}"
DB="${HOME}/.copilot/session-store.db"

if [ ! -f "$DB" ]; then
  echo "Error: session-store.db not found at $DB" >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "Error: sqlite3 is required but not installed." >&2
  exit 1
fi

echo "Copilot token usage — last ${DAYS} day(s)"
echo "Source: ${DB}"
echo

echo "## Daily breakdown"
sqlite3 -header -column "$DB" "
SELECT
  substr(created_at, 1, 10)                                              AS day,
  SUM(input_tokens)                                                      AS input,
  SUM(output_tokens)                                                     AS output,
  SUM(cache_read_tokens)                                                 AS cache_read,
  SUM(cache_write_tokens)                                                AS cache_write,
  SUM(input_tokens + output_tokens + cache_read_tokens + cache_write_tokens) AS total
FROM assistant_usage_events
WHERE substr(created_at, 1, 10) >= date('now', '-${DAYS} days')
GROUP BY day
ORDER BY day;
"

echo
echo "## Summary"
sqlite3 -header -column "$DB" "
SELECT
  COUNT(DISTINCT substr(created_at, 1, 10))                                       AS active_days,
  SUM(input_tokens + output_tokens + cache_read_tokens + cache_write_tokens)       AS total_tokens,
  ROUND(SUM(input_tokens + output_tokens + cache_read_tokens + cache_write_tokens) * 1.0 / ${DAYS}, 0) AS avg_per_calendar_day,
  ROUND(SUM(input_tokens + output_tokens + cache_read_tokens + cache_write_tokens) * 1.0
        / MAX(COUNT(DISTINCT substr(created_at, 1, 10)), 1), 0)                    AS avg_per_active_day
FROM assistant_usage_events
WHERE substr(created_at, 1, 10) >= date('now', '-${DAYS} days');
"
