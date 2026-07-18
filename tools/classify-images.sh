#!/usr/bin/env bash
set -euo pipefail

xpad_image_dir="${1:-./my-xpad2-bootchain}"

xpad_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

xpad_classify_hash() {
  case "$1" in
    ee05973a30f3fd4a6f1ca344856784f96e7a6b630333ba25dc776205d3713f11)
      printf 'V231227 preloader raw A/B'
      ;;
    304a9757cd859cc437326e678e5f664a30026826e318866c9c31e5d9d435694e)
      printf 'V231227 preloader UFS boot LUN'
      ;;
    a87979a827c005107c68395c88396ce14a418dff0a23f89d473797e1476b3296)
      printf 'V231227 valid lk_a'
      ;;
    2daeb1f36095b44b318410b3f4e8b5d989dcc7bb023d1426c492dab0a3053e74)
      printf '8 MiB all-zero lk_b; DO NOT USE'
      ;;
    6ebc4667ef9c0a6a888bda6d020cd744967e966c63b4d0ee6a07e5a21bce3b6a)
      printf 'confirmed V260523 lk_a'
      ;;
    4b5f932dee1d3d6f42a23a4f25c058fae7c7c14488b44d5df0959c6c7252f80e)
      printf 'observed V260629 lk_b comparison image'
      ;;
    *)
      printf 'unknown'
      ;;
  esac
}

if [[ ! -d "${xpad_image_dir}" ]]; then
  printf 'error: image directory not found: %s\n' "${xpad_image_dir}" >&2
  exit 1
fi

printf 'bytes\tsha256\tclassification\tfile\n'
while IFS= read -r -d '' xpad_file; do
  xpad_bytes="$(wc -c < "${xpad_file}" | tr -d ' ')"
  xpad_digest="$(xpad_sha256 "${xpad_file}")"
  xpad_class="$(xpad_classify_hash "${xpad_digest}")"
  printf '%s\t%s\t%s\t%s\n' \
    "${xpad_bytes}" "${xpad_digest}" "${xpad_class}" "${xpad_file}"
done < <(find "${xpad_image_dir}" -maxdepth 1 -type f -name '*.img' -print0 | sort -z)
