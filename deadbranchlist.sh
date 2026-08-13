#!/usr/bin/env bash
#
# deadbranchlist.sh
#
# Identifies local git branches with no matching remote branch (never pushed,
# or pushed then deleted after merge/close) and writes a dated markdown
# report for manual review. Does NOT delete any branches.
#
# Usage: deadbranchlist.sh <path-to-repo>
#
# Example: deadbranchlist.sh ~/Documents/Projects/USCS-BE

set -euo pipefail

# ---------------------------------------------------------------------------
# Tailor this to change where reports are written.
REPORT_DIR="$HOME/Documents/Docs/Copilot/branch-reports"
# ---------------------------------------------------------------------------

usage() {
    echo "Usage: $(basename "$0") <path-to-repo>" >&2
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi

REPO_PATH="$1"

if [ ! -d "$REPO_PATH" ]; then
    echo "Error: '$REPO_PATH' is not a directory." >&2
    exit 1
fi

if ! git -C "$REPO_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: '$REPO_PATH' is not a git repository." >&2
    exit 1
fi

mkdir -p "$REPORT_DIR"

REPO_ABS_PATH=$(cd "$REPO_PATH" && pwd)
REPORT_DATE=$(date +"%Y-%m-%d")
REPORT_TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
REPORT_FILE="$REPORT_DIR/branch-report-${REPORT_TIMESTAMP}.md"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

LOCAL_BRANCHES="$TMP_DIR/local_branches.txt"
REMOTE_BRANCHES="$TMP_DIR/remote_branches.txt"
CANDIDATES="$TMP_DIR/candidates.txt"

git -C "$REPO_PATH" fetch --prune origin

git -C "$REPO_PATH" branch --format='%(refname:short)' | sort > "$LOCAL_BRANCHES"
git -C "$REPO_PATH" branch -r --format='%(refname:short)' | sed 's#^origin/##' | sort > "$REMOTE_BRANCHES"
comm -23 "$LOCAL_BRANCHES" "$REMOTE_BRANCHES" > "$CANDIDATES"

CURRENT_BRANCH=$(git -C "$REPO_PATH" branch --show-current)

# Map branch name -> worktree path (if checked out in another worktree).
WORKTREE_MAP="$TMP_DIR/worktree_map.txt"
git -C "$REPO_PATH" worktree list | while read -r line; do
    path=$(echo "$line" | awk '{print $1}')
    branch=$(echo "$line" | sed -n 's/.*\[\(.*\)\]$/\1/p')
    if [ -n "$branch" ]; then
        printf '%s\t%s\n' "$branch" "$path" >> "$WORKTREE_MAP"
    fi
done
[ -f "$WORKTREE_MAP" ] || touch "$WORKTREE_MAP"

{
    echo "# Branch Cleanup Review — ${REPORT_DATE}"
    echo
    echo "Repo: ${REPO_ABS_PATH}"
    echo
    echo "Local branches with no matching remote branch. Nothing has been deleted — review and confirm before removing any."
    echo
    echo "| Branch | Last Commit Date | Last Commit Message | Notes |"
    echo "|---|---|---|---|"
} > "$REPORT_FILE"

# Build rows, then sort by commit date (oldest first) before appending.
ROWS_FILE="$TMP_DIR/rows.txt"
: > "$ROWS_FILE"

while IFS= read -r branch; do
    [ -z "$branch" ] && continue

    commit_info=$(git -C "$REPO_PATH" log -1 --format='%ad|%s' --date=short "$branch" 2>/dev/null || true)
    commit_date=$(echo "$commit_info" | cut -d'|' -f1)
    commit_msg=$(echo "$commit_info" | cut -d'|' -f2-)
    commit_msg=${commit_msg//|/\\|}

    note=""
    if [ "$branch" = "$CURRENT_BRANCH" ]; then
        note="current branch (main checkout)"
    else
        wt_path=$(awk -F'\t' -v b="$branch" '$1 == b {print $2; exit}' "$WORKTREE_MAP" 2>/dev/null || true)
        if [ -n "$wt_path" ]; then
            note="checked out in worktree at ${wt_path}"
        fi
    fi

    printf '%s\t%s\t%s\t%s\n' "$commit_date" "$branch" "$commit_msg" "$note" >> "$ROWS_FILE"
done < "$CANDIDATES"

sort "$ROWS_FILE" | while IFS=$'\t' read -r date branch msg note; do
    echo "| ${branch} | ${date} | ${msg} | ${note} |" >> "$REPORT_FILE"
done

TOTAL=$(wc -l < "$CANDIDATES" | tr -d ' ')

echo "Report written to: $REPORT_FILE"
echo "Candidate dead branches found: $TOTAL"
