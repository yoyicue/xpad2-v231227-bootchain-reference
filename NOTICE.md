# Notice

The Git source tree excludes OEM preloader and LK binary images. The `v231227-r2` GitHub Release separately provides the V231227 `preloader_raw_a.img` and `lk_a.img` reference images. The `ls12-lk-2024-observed-r1` release is displayed as XPad2 LS12 V241216 Boot Chain r1 and provides the confirmed current-system V241216 / incremental 19 `lk_b` together with a retained older `lk_a` whose incremental 1723478295 is confirmed and V240813 attribution remains inferred. The `ls12-lk-v260523-r1` release combines version-confirmed V260523 preloader and LK samples. The `ls12-v260629-restricted-fastboot-r1` release provides the confirmed V260629 preloader and the LK with its standard Fastboot `flash:` / `erase:` command entries removed. All are identified by SHA-256 in `metadata/bootchain-hashes.tsv`.

The included SHA-256 values identify firmware observed on an owned TALIH-PD2 / XPad2 and are provided for interoperability, recovery research, and integrity checks. The release assets remain OEM firmware and are not covered by this repository's MIT license. Other firmware images are outside these releases' scope.

The extraction tooling is read-only with respect to the Android device. It requires root access that the device owner has already authorized and does not attempt to obtain root, unlock the bootloader, bypass signature checks, or write partitions.

Contributors must not submit device-unique data, credentials, raw user data, or additional firmware images without a separate publication review.
