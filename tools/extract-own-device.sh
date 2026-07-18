#!/usr/bin/env bash
set -euo pipefail

xpad_adb_bin="${ADB_BIN:-adb}"
xpad_su_bin="${SU_BIN:-su}"
xpad_output_dir="${1:-./my-xpad2-bootchain}"

xpad_adb() {
  if [[ -n "${ADB_SERIAL:-}" ]]; then
    "${xpad_adb_bin}" -s "${ADB_SERIAL}" "$@"
  else
    "${xpad_adb_bin}" "$@"
  fi
}

xpad_prop() {
  xpad_adb shell getprop "$1" | tr -d '\r'
}

xpad_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

if ! command -v "${xpad_adb_bin}" >/dev/null 2>&1; then
  printf 'error: adb executable not found: %s\n' "${xpad_adb_bin}" >&2
  exit 1
fi

xpad_adb get-state >/dev/null

xpad_model="$(xpad_prop ro.product.model)"
xpad_device="$(xpad_prop ro.product.device)"
xpad_vendor_device="$(xpad_prop ro.product.vendor.device)"
xpad_platform="$(xpad_prop ro.board.platform)"
xpad_version="$(xpad_prop ro.genie.gota.version)"
xpad_incremental="$(xpad_prop ro.build.version.incremental)"

case "${xpad_model}|${xpad_device}|${xpad_vendor_device}" in
  *TALIH_PD2*|*TALIH-PD2*|*ls12_mt8797_wifi_64*) ;;
  *)
    printf 'error: device is not recognized as TALIH-PD2/XPad2\n' >&2
    printf 'observed model=%s device=%s vendor_device=%s\n' \
      "${xpad_model}" "${xpad_device}" "${xpad_vendor_device}" >&2
    exit 1
    ;;
esac

xpad_root_uid="$(xpad_adb shell "${xpad_su_bin} -c 'id -u'" | tr -d '\r')"
if [[ "${xpad_root_uid}" != "0" ]]; then
  printf 'error: authorized root is required; observed uid=%s\n' "${xpad_root_uid}" >&2
  exit 1
fi

mkdir -p "${xpad_output_dir}"
xpad_manifest="${xpad_output_dir}/manifest.tsv"
xpad_metadata="${xpad_output_dir}/device.txt"

if [[ -e "${xpad_manifest}" || -e "${xpad_metadata}" ]]; then
  printf 'error: output directory already contains extraction metadata: %s\n' \
    "${xpad_output_dir}" >&2
  exit 1
fi

{
  printf 'model=%s\n' "${xpad_model}"
  printf 'device=%s\n' "${xpad_device}"
  printf 'vendor_device=%s\n' "${xpad_vendor_device}"
  printf 'platform=%s\n' "${xpad_platform}"
  printf 'firmware=%s\n' "${xpad_version}"
  printf 'incremental=%s\n' "${xpad_incremental}"
  printf 'serial_included=no\n'
} > "${xpad_metadata}"

printf 'name\tdevice\tbytes\tdevice_sha256\tlocal_sha256\n' > "${xpad_manifest}"

xpad_extract_one() {
  local xpad_name="$1"
  local xpad_device_path="$2"
  local xpad_target="${xpad_output_dir}/${xpad_name}.img"
  local xpad_partial="${xpad_target}.partial"
  local xpad_remote_size
  local xpad_remote_hash
  local xpad_local_size
  local xpad_local_hash

  if [[ -e "${xpad_target}" || -e "${xpad_partial}" ]]; then
    printf 'error: refusing to overwrite %s\n' "${xpad_target}" >&2
    exit 1
  fi

  xpad_remote_size="$(
    xpad_adb shell "${xpad_su_bin} -c 'blockdev --getsize64 ${xpad_device_path}'" |
      tr -d '\r'
  )"
  xpad_remote_hash="$(
    xpad_adb shell "${xpad_su_bin} -c 'sha256sum ${xpad_device_path}'" |
      awk '{print $1}' | tr -d '\r'
  )"

  printf 'extracting %s (%s bytes)\n' "${xpad_name}" "${xpad_remote_size}"
  xpad_adb exec-out "${xpad_su_bin} -c 'cat ${xpad_device_path}'" > "${xpad_partial}"

  xpad_local_size="$(wc -c < "${xpad_partial}" | tr -d ' ')"
  xpad_local_hash="$(xpad_sha256 "${xpad_partial}")"

  if [[ "${xpad_local_size}" != "${xpad_remote_size}" ]]; then
    printf 'error: size mismatch for %s: local=%s device=%s\n' \
      "${xpad_name}" "${xpad_local_size}" "${xpad_remote_size}" >&2
    exit 1
  fi
  if [[ "${xpad_local_hash}" != "${xpad_remote_hash}" ]]; then
    printf 'error: hash mismatch for %s\n' "${xpad_name}" >&2
    exit 1
  fi

  mv "${xpad_partial}" "${xpad_target}"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "${xpad_name}" "${xpad_device_path}" "${xpad_local_size}" \
    "${xpad_remote_hash}" "${xpad_local_hash}" >> "${xpad_manifest}"
}

xpad_extract_one preloader_raw_a /dev/block/mapper/pl_a
xpad_extract_one preloader_raw_b /dev/block/mapper/pl_b
xpad_extract_one lk_a /dev/block/by-name/lk_a
xpad_extract_one lk_b /dev/block/by-name/lk_b

printf 'complete: %s\n' "${xpad_output_dir}"
printf 'manifest: %s\n' "${xpad_manifest}"
