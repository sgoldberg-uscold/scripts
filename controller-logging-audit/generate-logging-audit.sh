#!/usr/bin/env bash
# generate-logging-audit.sh
#
# Fetches 5xx error data from Azure Log Analytics and generates controller
# logging audit reports for USCS-BE and USCS-RF-BE.
#
# Usage:
#   ./generate-logging-audit.sh [--days N] [--output-dir DIR]
#
# Requirements:
#   - az CLI installed and logged in (run `az login` if needed)
#   - python3 on PATH
#   - USCS-BE and USCS-RF-BE cloned under ~/Documents/Projects/

set -euo pipefail

# ─── Config ────────────────────────────────────────────────────────────────────
WORKSPACE_ID="04e12ce3-4609-4e6c-a8da-78094d692902"
USCS_BE_DIR="$HOME/Documents/Projects/USCS-BE"
USCS_RF_BE_DIR="$HOME/Documents/Projects/USCS-RF-BE"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/reports"
DAYS=30

# ─── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --days)    DAYS="$2";       shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_DIR="$OUTPUT_DIR/$TIMESTAMP"
mkdir -p "$REPORT_DIR"

AUDIT_PY="$SCRIPT_DIR/controller_logging_audit.py"
NGINX_DATA="$REPORT_DIR/5xx_endpoints.txt"

echo "========================================================"
echo " Controller Logging Audit"
echo " Date     : $(date '+%Y-%m-%d %H:%M:%S')"
echo " Lookback : ${DAYS} days"
echo " Output   : $REPORT_DIR"
echo "========================================================"
echo ""

# ─── Step 1: Fetch 5xx data from Azure ────────────────────────────────────────
echo "[1/3] Fetching 5xx error data from Azure Log Analytics..."

TOKEN=$(az account get-access-token \
  --resource "https://api.loganalytics.io" \
  --query accessToken -o tsv 2>/dev/null)

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: Could not obtain Azure access token. Run 'az login' first."
  exit 1
fi

KQL_QUERY="ProductionNginxAccess_CL \
| where TimeGenerated >= ago(${DAYS}d) \
| where code_d >= 500 \
| where isnotempty(uri_s) \
| summarize errorCount = count() by uri_s \
| sort by errorCount desc"

HTTP_RESPONSE=$(curl -s -X POST \
  "https://api.loganalytics.io/v1/workspaces/${WORKSPACE_ID}/query" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"$KQL_QUERY\", \"timespan\": \"P${DAYS}D\"}")

python3 - << PYEOF
import json, sys

data = json.loads('''$HTTP_RESPONSE''')
if 'tables' not in data:
    print("ERROR: Unexpected response from Log Analytics:")
    print(json.dumps(data)[:500])
    sys.exit(1)

cols = [c['name'] for c in data['tables'][0]['columns']]
rows = data['tables'][0]['rows']
with open('$NGINX_DATA', 'w') as f:
    for row in rows:
        d = dict(zip(cols, row))
        f.write(f"{int(d['errorCount'])}\t{d['uri_s']}\n")
print(f"  Saved {len(rows)} distinct 5xx endpoints to $NGINX_DATA")
PYEOF

echo ""

# ─── Step 2: Run audit on both projects ────────────────────────────────────────
echo "[2/3] Running audit on USCS-BE..."
python3 "$AUDIT_PY" \
  "$USCS_BE_DIR" \
  "$REPORT_DIR/audit-USCS-BE.txt" \
  "$NGINX_DATA"

echo ""
echo "[3/3] Running audit on USCS-RF-BE..."
python3 "$AUDIT_PY" \
  "$USCS_RF_BE_DIR" \
  "$REPORT_DIR/audit-USCS-RF-BE.txt" \
  "$NGINX_DATA"

# ─── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "========================================================"
echo " Reports saved to: $REPORT_DIR"
echo "   audit-USCS-BE.txt"
echo "   audit-USCS-RF-BE.txt"
echo "   5xx_endpoints.txt  (raw nginx data)"
echo "========================================================"
