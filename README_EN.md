# XPad2 V231227 Boot-Chain Reference

This repository documents the V231227 boot chain used by TALIH-PD2 / XPad2.
It is intended for same-model ROM, recovery, and bootloader research.

The repository contains sanitized metadata, known hashes, LK comparisons, and
read-only owner-extraction tools. Firmware samples are distributed only as
separate release assets. No flashing automation is included.

## Scope

- Product: TALIH-PD2 / XPad2
- Platform: `ls12_mt8797_wifi_64`
- SoC family: MediaTek MT8797
- Legacy firmware: V231227, Android 13
- Confirmed intermediate firmware: V260523, incremental `239`, cross-checked
  between the official OTA and device slot A
- Compared firmware: V260629, incremental `260`, observed from device slot B
- Additional samples: LS12 LK builds dated 2024-08-13 and 2024-12-16, with
  provisional version attribution

These files are not portable to another model merely because it uses the same SoC.
DRAM, UFS, PMIC, panel, partition layout, rollback state, and signing roots can all
differ.

## Findings

- The usable V231227 bootloader is `lk_a.img`.
- The captured V231227 `lk_b.img` is an all-zero 8 MiB partition and must not be
  treated as a bootloader image.
- V231227 preloader raw A and B images are byte-identical.
- The observed V260629 slot-B LK retains fastboot initialization and read/control
  commands, but no longer contains the canonical `flash:` or `erase:` command
  strings. This establishes that the standard command entries are absent; it does
  not establish that every low-level storage-write helper was removed.
- Both 2024 LS12 observation samples retain `flash:` and `erase:`, but they came
  from a mixed-slot device backup and must not be identified as V260213 merely
  from the archive directory name.
- The confirmed V260523 LK also retains `flash:` and `erase:`. Zero-padding the
  official OTA LK to the 8 MiB partition size exactly reproduces the slot-A
  image read from the device.
- The removal is therefore currently bounded to the interval after V260523 and
  by V260629; it is inaccurate to describe every V260 build as restricted.
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

## V260523 LK download

The [`ls12-lk-v260523-r1` release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/ls12-lk-v260523-r1)
provides the version-confirmed
[`lk_a-v260523.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-lk-v260523-r1/lk_a-v260523.img):

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `lk_a-v260523.img` | 8,388,608 | `6ebc4667ef9c0a6a888bda6d020cd744967e966c63b4d0ee6a07e5a21bce3b6a` |

The version is supported by the official V260523 A/B OTA (incremental `239`)
and LK Build ID
`ls12_mt8797_wifi_64-dfde152c-20241118095326-20260523165450`. The OTA payload
`lk.img` is 1,261,568 bytes with SHA-256
`9e987c2359982f0b2cabbf1e0fb756dd156d3af67f5cb8c423bad3fc9cd2139d`.
Zero-padding it to 8 MiB exactly matches the device slot-A partition image.

## LS12 2024 LK observation samples

The [`ls12-lk-2024-observed-r1` release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/ls12-lk-2024-observed-r1)
contains two LK samples from one mixed-slot device backup:

| Asset | SHA-256 | Internal build date | Provisional attribution |
| --- | --- | --- | --- |
| [`lk_a-build-20240813-observed.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-lk-2024-observed-r1/lk_a-build-20240813-observed.img) | `ad8f5ea2b16efd60eb72045b35263b8c290dc5b151d75045e78b2af9a83434bf` | 2024-08-13 | suspected V240813, medium confidence; original `lk_a` |
| [`lk_b-build-20241216-observed.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-lk-2024-observed-r1/lk_b-build-20241216-observed.img) | `c87d7cd3903ceccd82a2fb6f4ac127434091ba0e4691d331511e35bb44654419` | 2024-12-16 | V241216-era, high confidence; original `lk_b` |

The paired system reports `ro.genie.gota.version=V241216`, and the `lk_b`,
`boot_b`, and `vendor_b` build times converge on 2024-12-16. Only the internal
Build ID supports the 2024-08-13 attribution for `lk_a`. The source is not an OTA
package with authoritative update metadata, so the assets use `observed` naming.
Their SHA-256 values remain the stable identities if later evidence refines the
version labels.

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
the property of its respective rights holders and release assets are not
MIT-licensed. Other OEM firmware and device-unique data are outside the scope of
these releases.

Writing preloader or LK is a high-risk operation. A correct checksum does not make
these images portable across products or board revisions, and a wrong preloader
write can remove both display and USB recovery paths. No flashing command is
provided by this project.
