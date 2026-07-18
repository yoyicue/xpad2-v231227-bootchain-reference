# XPad2 V231227 Boot-Chain Reference

This repository documents the V231227 boot chain used by TALIH-PD2 / XPad2.
It is intended for same-model ROM, recovery, and bootloader research.

The repository contains sanitized metadata, known hashes, Preloader/LK comparisons,
and read-only owner-extraction tools. Firmware samples are distributed only as
separate release assets. No flashing automation is included.

## Scope

- Product: TALIH-PD2 / XPad2
- Platform: `ls12_mt8797_wifi_64`
- SoC family: MediaTek MT8797
- Legacy firmware: V231227, Android 13
- Confirmed intermediate firmware: V260523, incremental `239`, cross-checked
  between the official OTA and device slot A
- Restricted-Fastboot firmware: V260629, incremental `260`, cross-checked
  between the official OTA and device slot B
- V241216 mixed-slot sample: current slot B is confirmed as V241216 / incremental
  `19`; retained slot A is suspected V240813 / incremental `1723478295`

These files are not portable to another model merely because it uses the same SoC.
DRAM, UFS, PMIC, panel, partition layout, rollback state, and signing roots can all
differ.

## Boot-chain evolution overview

The repository no longer treats the evidence as only an “old V231227” versus a
generic “V260” comparison. It follows five incrementals from the same LS12 product
line:

```text
1703659196 → 1723478295 → 19 → 239 → 260
   V231227    2024 slot A  V241216  V260523  V260629
```

Incremental `1723478295` is tied to the retained slot A and a 2024-08-13 LK Build
ID. V240813 is a high-confidence inference, not a directly confirmed product
version. Incrementals `19`, `239`, and `260` are confirmed as V241216, V260523,
and V260629 respectively.

| Stage | Preloader entry policy | LK Fastboot capability | Interpretation |
| --- | --- | --- | --- |
| `1703659196` | Accepts early `FASTBOOT`, acknowledges with `TOOBTSAF`, sets mode 99 | Retains `flash:` and `erase:` | Full baseline |
| `1723478295` | Same early entry path | Same command surface | Minor rebuild; stable capability |
| `19` | Same early entry path | Same command surface | V241216 baseline |
| `239` | Executable code matches `19`; GFH security field and signatures change | Same source-revision marker as `19`; write/erase entries remain | Last confirmed full sample |
| `260` | Recognizes early `FASTBOOT` but rejects it for the user build and no longer switches mode | Standard `flash:` / `erase:` registrations removed; storage backends remain | Both layers restricted |

The confirmed transition is therefore not “every V260 build is trimmed.” It is a
coordinated restriction introduced after V260523 / incremental `239` and by
V260629 / incremental `260`: the preloader's early Fastboot entry and LK's standard
write/erase command entries are both restricted. Missing 2025 dumps do not change
this 37-day bound, but they limit claims about every intermediate build.

## Findings

- The usable V231227 bootloader is `lk_a.img`.
- The captured V231227 `lk_b.img` is an all-zero 8 MiB partition and must not be
  treated as a bootloader image.
- V231227 preloader raw A and B images are byte-identical.
- The V231227, two 2024-observed, and V260523 preloaders acknowledge the early
  BLDR `FASTBOOT` token with `TOOBTSAF` and set the Fastboot boot mode. V260629
  instead reports `user version not supported`, sends no acknowledgement, and
  no longer sets that mode.
- The confirmed V260629 slot-B LK retains fastboot initialization and read/control
  commands, but no longer contains the canonical `flash:` or `erase:` command
  strings. This establishes that the standard command entries are absent; it does
  not establish that every low-level storage-write helper was removed. Paths such
  as `storage_write`, `storage_erase`, `partition_write`, and the UFS/eMMC backends
  remain present.
- The current V241216 slot-B LK and retained older slot-A LK both preserve
  `flash:` and `erase:`. Slot B is confirmed as V241216 / incremental `19`;
  slot A is strongly suspected V240813.
- The confirmed V260523 LK also retains `flash:` and `erase:`. Zero-padding the
  official OTA LK to the 8 MiB partition size exactly reproduces the slot-A
  image read from the device.
- Among current samples, V260523 is the last confirmed LS12 version retaining
  both the preloader's early Fastboot entry and LK's standard `flash:` / `erase:`
  entries. V260629 restricts both layers.
- Both changes are bounded to after V260523 / incremental `239` and by V260629 /
  incremental `260`, a 37-day window. Missing 2025 dumps do not affect this bound,
  but they prevent claims about every intermediate build.
- The A/B LK partition sizes and layout did not change.

See [the five-sample boot-chain evolution report](reports/bootchain-evolution-1703659196-to-260.md),
[the BootROM / Preloader verification report](reports/bootrom-preloader-verification.md),
[the LK comparison](reports/lk-v231227-vs-v260.md), and
[machine-readable hashes](metadata/bootchain-hashes.tsv).

## V231227 LS12 boot-chain downloads

The [`v231227-r2` release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/v231227-r2)
is displayed as **XPad2 LS12 V231227 boot-chain images r2** and contains these
firmware assets:

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| [`preloader_raw_a.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/v231227-r2/preloader_raw_a.img) | 4,190,208 | `ee05973a30f3fd4a6f1ca344856784f96e7a6b630333ba25dc776205d3713f11` |
| [`lk_a.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/v231227-r2/lk_a.img) | 8,388,608 | `a87979a827c005107c68395c88396ce14a418dff0a23f89d473797e1476b3296` |

`preloader_raw_b.img` is byte-identical to A and is therefore not duplicated. The
all-zero V231227 `lk_b.img` is unusable and is not published. The released
`preloader_raw_a.img` is the 4,190,208-byte raw mapper read, not the 4,194,304-byte
boot-LUN dump; do not infer a write format from its filename or mix the two forms.

## V260523 boot-chain download

The [`ls12-lk-v260523-r1` release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/ls12-lk-v260523-r1)
combines the version-confirmed preloader and LK samples:

Among current samples, V260523 is the last confirmed LS12 release retaining both
the preloader's early Fastboot entry and LK's `flash:` / `erase:` entries;
V260629 restricts both layers.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| [`preloader_raw_a-v260523.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-lk-v260523-r1/preloader_raw_a-v260523.img) | 4,190,208 | `97cbf6d20e7e9cdffceb52a434bcb7ed5675c4eb055112ee90d2037374d3b54b` |
| [`lk_a-v260523.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-lk-v260523-r1/lk_a-v260523.img) | 8,388,608 | `6ebc4667ef9c0a6a888bda6d020cd744967e966c63b4d0ee6a07e5a21bce3b6a` |

The version is supported by the official V260523 A/B OTA (incremental `239`)
and LK Build ID
`ls12_mt8797_wifi_64-dfde152c-20241118095326-20260523165450`. The OTA payload
`lk.img` is 1,261,568 bytes with SHA-256
`9e987c2359982f0b2cabbf1e0fb756dd156d3af67f5cb8c423bad3fc9cd2139d`.
Zero-padding it to 8 MiB exactly matches the device slot-A partition image.

The OTA `preloader_raw.img` is 495,616 bytes with SHA-256
`cede4da9c9a4ec48914fa8eb321e686e6176617227c44df5fbe0d941c77e4aa7`.
Zero-padding it to the 4,190,208-byte mapper raw format produces the released
image and exactly matches the device slot-A read. This is not a 4,194,304-byte
boot-LUN dump.

## V260629 restricted-Fastboot boot-chain download

The [`ls12-v260629-restricted-fastboot-r1` release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/ls12-v260629-restricted-fastboot-r1)
provides the version-confirmed V260629 preloader and LK:

This is the restricted-Fastboot sample discussed here. The preloader still
recognizes the early `FASTBOOT` token but reports that the user build is unsupported,
sends no `TOOBTSAF` acknowledgement, and no longer sets Fastboot boot mode. LK still
retains Fastboot initialization, `getvar:`, `download:`, `boot`, `continue`, reboot,
and slot-control entries, while the standard `flash:` and `erase:` registrations
are gone. “Restricted” does not mean that Fastboot, DA authentication, or every
low-level storage helper was removed.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| [`preloader_raw_b-v260629.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-v260629-restricted-fastboot-r1/preloader_raw_b-v260629.img) | 4,190,208 | `76e76d566b48d21387daabc7cbd2e972782995cebd4c07cd01cc5e3e823636f4` |
| [`lk_b-v260629.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-v260629-restricted-fastboot-r1/lk_b-v260629.img) | 8,388,608 | `4b5f932dee1d3d6f42a23a4f25c058fae7c7c14488b44d5df0959c6c7252f80e` |

Identity is established by the official LS12 V260629 A/B OTA (incremental `260`),
LK Build ID
`ls12_mt8797_wifi_64-405e7a01-20260602101307-20260629041106`, and slot-B reads
from two devices. Zero-padding the 495,616-byte OTA preloader and 1,257,472-byte
OTA LK to their mapper raw / partition sizes exactly reproduces the device hashes.
The preloader asset is the 4,190,208-byte mapper raw form, not a boot-LUN dump.

## V241216 current system and retained slot-A LK

The [`ls12-lk-2024-observed-r1` release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/ls12-lk-2024-observed-r1)
is displayed as **XPad2 LS12 V241216 Boot Chain r1** and contains the current
slot-B LK plus the retained older slot-A LK from one device dump:

| Asset | Original partition | Incremental | Attribution |
| --- | --- | --- | --- |
| [`lk_a-build-20240813-observed.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-lk-2024-observed-r1/lk_a-build-20240813-observed.img) | retained `lk_a` | `1723478295` | suspected V240813, high confidence |
| [`lk_b-build-20241216-observed.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-lk-2024-observed-r1/lk_b-build-20241216-observed.img) | current `lk_b` | `19` | confirmed V241216 |

The current system directly reports `ro.genie.gota.version=V241216` and
`ro.build.version.incremental=19`. Signed descriptors in `boot_b`, `vbmeta_b`,
`vbmeta_system_b`, and `vbmeta_vendor_b` also use incremental `19`, and their
dates converge with `lk_b` on 2024-12-16. The dump provider reports the UI version
as `V2.4.0`; this human-sourced product version is recorded separately from the
image-confirmed V241216 / incremental `19` identity.

Signed descriptors in `boot_a`, `vbmeta_a`, `vbmeta_system_a`, and
`vbmeta_vendor_a` consistently record incremental `1723478295`, corresponding to
2024-08-12 23:58:15 CST. The `lk_a` final Build ID is dated 2024-08-13 02:11:05.
This strongly supports V240813, but no direct slot-A
`ro.genie.gota.version=V240813` string has been recovered. Asset names retain
`observed`, and SHA-256 remains their stable identity.

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
