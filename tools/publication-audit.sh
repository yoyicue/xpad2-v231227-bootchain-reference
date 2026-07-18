#!/usr/bin/env bash
set -euo pipefail

xpad_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
xpad_failures=0

xpad_fail() {
  printf 'FAIL: %s\n' "$1" >&2
  xpad_failures=$((xpad_failures + 1))
}

printf 'checking for prohibited binary artifacts\n'
while IFS= read -r -d '' xpad_path; do
  xpad_rel="${xpad_path#${xpad_repo_dir}/}"
  xpad_fail "prohibited artifact present: ${xpad_rel}"
done < <(
  find "${xpad_repo_dir}" -type f \
    \( -name '*.img' -o -name '*.bin' -o -name '*.raw' -o -name '*.dump' \
       -o -name '*.tar' -o -name '*.zip' -o -name '*.7z' \) -print0
)

printf 'checking for prohibited partition names in published artifacts\n'
while IFS= read -r xpad_hit; do
  [[ -z "${xpad_hit}" ]] || xpad_fail "sensitive partition reference: ${xpad_hit}"
done < <(
  find "${xpad_repo_dir}" -type f \
    \( -path '*/artifacts/*' -o -path '*/captures/*' \) -print 2>/dev/null || true
)

printf 'checking for device identity fields\n'
if rg -n -i \
  'androidboot\.(serialno|bsn)|\[ro\.serialno\]|wifi[^[:alnum:]]*mac|bluetooth[^[:alnum:]]*(mac|address)' \
  "${xpad_repo_dir}" \
  --glob '!tools/publication-audit.sh' \
  --glob '!.git/**'; then
  xpad_fail 'device identity field found'
fi

printf 'checking for local absolute paths\n'
if rg -n \
  '/Users/|/Volumes/|/home/[[:alnum:]_.-]+/' \
  "${xpad_repo_dir}" \
  --glob '!tools/publication-audit.sh' \
  --glob '!.git/**'; then
  xpad_fail 'local absolute path found'
fi

printf 'checking scripts\n'
bash -n "${xpad_repo_dir}/tools/extract-own-device.sh"
bash -n "${xpad_repo_dir}/tools/classify-images.sh"
bash -n "${xpad_repo_dir}/tools/publication-audit.sh"

if [[ "${xpad_failures}" -ne 0 ]]; then
  printf 'publication audit failed: %d issue(s)\n' "${xpad_failures}" >&2
  exit 1
fi

printf 'publication audit passed\n'
