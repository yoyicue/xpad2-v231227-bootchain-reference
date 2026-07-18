# XPad2 V231227 Boot-Chain Reference

This repository documents the V231227 boot chain used by TALIH-PD2 / XPad2.
It is intended for same-model ROM, recovery, and bootloader research.

The repository contains sanitized metadata, known hashes, an LK comparison, and
read-only owner-extraction tools. Two unmodified V231227 reference images are
available separately in the `v231227-r2` release. No flashing automation is
included.

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

## V231227 image downloads

The [`v231227-r2` release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/v231227-r2)
contains exactly these firmware assets:

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| [`preloader_raw_a.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/v231227-r2/preloader_raw_a.img) | 4,190,208 | `ee05973a30f3fd4a6f1ca344856784f96e7a6b630333ba25dc776205d3713f11` |
| [`lk_a.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/v231227-r2/lk_a.img) | 8,388,608 | `a87979a827c005107c68395c88396ce14a418dff0a23f89d473797e1476b3296` |

`preloader_raw_b.img` is byte-identical to A and is therefore not duplicated. The
all-zero V231227 `lk_b.img` is unusable and is not published. The released
`preloader_raw_a.img` is the 4,190,208-byte raw mapper read, not the 4,194,304-byte
boot-LUN dump; do not infer a write format from its filename or mix the two forms.

## Owner extraction

On an explicitly authorized, already-rooted XPad2:

```sh
./tools/extract-own-device.sh ./my-xpad2-bootchain
./tools/classify-images.sh ./my-xpad2-bootchain
```

The extractor reads only the preloader mapper and LK block devices. It does not
write Android partitions and refuses to overwrite local output files.

## Privacy and scope

Do not publish NVRAM, NVData, proinfo, persist, seccfg, efuse, OTP, userdata,
vendor logs, raw GPT images, unique GUIDs, serial numbers, MAC addresses, or
calibration data.

Repository-authored documentation and tools are MIT-licensed. OEM firmware remains
the property of its respective rights holders and the two release assets are not
MIT-licensed. Other OEM firmware and device-unique data are outside the scope of
this release.

Writing preloader or LK is a high-risk operation. A correct checksum does not make
these images portable across products or board revisions, and a wrong preloader
write can remove both display and USB recovery paths. No flashing command is
provided by this project.
