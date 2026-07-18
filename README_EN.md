# XPad2 V231227 Boot-Chain Reference

This repository documents the V231227 boot chain used by TALIH-PD2 / XPad2.
It is intended for same-model ROM, recovery, and bootloader research.

The public repository contains sanitized metadata, known hashes, an LK comparison,
and read-only tools that let owners extract images from their own device. It does
not redistribute proprietary firmware blobs and contains no flashing automation.

## Scope

- Product: TALIH-PD2 / XPad2
- Platform: `ls12_mt8797_wifi_64`
- SoC family: MediaTek MT8797
- Legacy firmware: V231227, Android 13
- Compared firmware: V260629, incremental `260`

These files are not portable to another model merely because it uses the same SoC.
DRAM, UFS, PMIC, panel, partition layout, rollback state, and signing roots can all
differ.

## Findings

- The usable V231227 bootloader is `lk_a.img`.
- The captured V231227 `lk_b.img` is an all-zero 8 MiB partition and must not be
  treated as a bootloader image.
- V231227 preloader raw A and B images are byte-identical.
- The observed V260 LK retains fastboot initialization and read/control commands,
  but no longer contains the canonical `flash:` or `erase:` command strings.
- The A/B LK partition sizes and layout did not change.

See [the LK comparison](reports/lk-v231227-vs-v260.md) and
[machine-readable hashes](metadata/bootchain-hashes.tsv).

## Owner extraction

On an explicitly authorized, already-rooted XPad2:

```sh
./tools/extract-own-device.sh ./my-xpad2-bootchain
./tools/classify-images.sh ./my-xpad2-bootchain
```

The extractor reads only the preloader mapper and LK block devices. It does not
write Android partitions and refuses to overwrite local output files.

## Privacy and redistribution

Do not publish NVRAM, NVData, proinfo, persist, seccfg, efuse, OTP, userdata,
vendor logs, raw GPT images, unique GUIDs, serial numbers, MAC addresses, or
calibration data.

Repository-authored documentation and tools are MIT-licensed. OEM firmware remains
the property of its respective rights holders. Extract images only from hardware
or firmware you are authorized to access.
