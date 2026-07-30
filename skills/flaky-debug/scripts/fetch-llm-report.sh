#!/usr/bin/env bash
set -euo pipefail

# Fetches the playwright-llm-report artifact from a GitHub Actions run.
# Uses the run ID in an atomic, locked extract directory so parallel downloads
# from different agents cannot publish partial reports.
#
# Usage: fetch-llm-report.sh <github-actions-url>
# Example: fetch-llm-report.sh 'https://github.com/Org/Repo/actions/runs/123'

url="${1:-}"

if [[ -z "$url" ]]; then
  echo "Usage: fetch-llm-report.sh <github-actions-url>" >&2
  exit 1
fi

# Parse owner, repo, run ID, and an optional attempt suffix from the URL.
if [[ "$url" =~ ^https?://github\.com/([^/]+)/([^/]+)/actions/runs/([0-9]+)(/attempts/([0-9]+))?/?$ ]]; then
  owner="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
  run_id="${BASH_REMATCH[3]}"
  run_attempt="${BASH_REMATCH[5]:-}"
else
  echo "Error: Could not parse GitHub Actions URL: $url" >&2
  exit 1
fi

if [[ -n "$run_attempt" ]]; then
  echo "Error: Attempt-qualified workflow URLs are not supported because the run artifact API does not expose artifact attempt provenance." >&2
  echo "Use the URL without /attempts/${run_attempt} only when the latest attempt is intended." >&2
  exit 1
fi

echo "Repo: ${owner}/${repo}, Run ID: ${run_id}"

# Fetch every page once, then find the newest non-expired report locally.
artifact_pages=$(gh api --paginate \
  "repos/${owner}/${repo}/actions/runs/${run_id}/artifacts?per_page=100")
artifact_json=$(printf '%s\n' "$artifact_pages" | jq -sc \
  '[.[].artifacts[] | select(.name == "playwright-llm-report" and (.expired | not))] | sort_by(.created_at) | last // empty | {id, name, size_in_bytes, expired}')

if [[ -z "$artifact_json" ]]; then
  echo "Error: No 'playwright-llm-report' artifact found for run ${run_id}" >&2
  echo "Available artifacts:" >&2
  printf '%s\n' "$artifact_pages" | jq -sr '.[].artifacts[].name' >&2
  exit 1
fi

artifact_id=$(echo "$artifact_json" | jq -r '.id')
expired=$(echo "$artifact_json" | jq -r '.expired')
size=$(echo "$artifact_json" | jq -r '.size_in_bytes')

if [[ "$expired" == "true" ]]; then
  echo "Error: Artifact has expired and is no longer available." >&2
  exit 1
fi

echo "Found artifact: id=${artifact_id}, size=${size} bytes"

# Download and extract using the run ID for isolation.
out_dir="/tmp/playwright-llm-report-${run_id}"
lock_dir="${out_dir}.lock"
completion_marker="${out_dir}/.complete"
expected_report="${out_dir}/llm-report.json"

report_is_complete() {
  [[ -f "$completion_marker" && -f "$expected_report" ]] &&
    [[ "$(<"$completion_marker")" == "$artifact_id" ]]
}

print_cached_report() {
  echo "Already downloaded — skipping."
  echo ""
  echo "Report directory: ${out_dir}"
}

if report_is_complete; then
  print_cached_report
  exit 0
fi

lock_acquired=false
for _ in {1..450}; do
  if mkdir "$lock_dir" 2>/dev/null; then
    lock_acquired=true
    break
  fi
  if report_is_complete; then
    print_cached_report
    exit 0
  fi

  sleep 2
done

if [[ "$lock_acquired" != "true" ]]; then
  echo "Error: Timed out after 15 minutes waiting for report download lock: ${lock_dir}" >&2
  exit 1
fi

tmp_zip=""
extract_dir=""
cleanup() {
  if [[ -n "$tmp_zip" ]]; then
    rm -f -- "$tmp_zip"
  fi
  if [[ -n "$extract_dir" && -d "$extract_dir" ]]; then
    rm -rf -- "$extract_dir"
  fi
  rmdir -- "$lock_dir" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Another process may have completed while this one was acquiring the lock.
if report_is_complete; then
  print_cached_report
  exit 0
fi

tmp_zip="$(mktemp "${out_dir}.zip.XXXXXX")"
extract_dir="$(mktemp -d "${out_dir}.extract.XXXXXX")"

echo "Downloading to a temporary file."
gh api "repos/${owner}/${repo}/actions/artifacts/${artifact_id}/zip" > "$tmp_zip"

echo "Extracting to a temporary directory."
unzip -q "$tmp_zip" -d "$extract_dir"

if [[ ! -f "$extract_dir/llm-report.json" ]]; then
  echo "Error: Downloaded artifact does not contain llm-report.json" >&2
  exit 1
fi

printf '%s\n' "$artifact_id" > "$extract_dir/.complete"
if [[ -e "$out_dir" ]]; then
  rm -rf -- "$out_dir"
fi
mv "$extract_dir" "$out_dir"
extract_dir=""

echo ""
echo "Done! Files:"
ls -la "$out_dir"
echo ""
echo "Report directory: ${out_dir}"
