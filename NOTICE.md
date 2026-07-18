# Notice

The Git source tree excludes OEM preloader and LK binary images. The `v231227-r2`
GitHub Release separately provides the V231227 `preloader_raw_a.img` and
`lk_a.img` reference images. The `ls12-lk-2024-observed-r1` release provides two
additional LK observation samples with provisional version attribution. All are
identified by SHA-256 in `metadata/bootchain-hashes.tsv`.

The included SHA-256 values identify firmware observed on an owned TALIH-PD2 / XPad2
and are provided for interoperability, recovery research, and integrity checks.
The release assets remain OEM firmware and are not covered by this repository's
MIT license. Other firmware images are outside these releases' scope.

The extraction tooling is read-only with respect to the Android device. It requires
root access that the device owner has already authorized and does not attempt to
obtain root, unlock the bootloader, bypass signature checks, or write partitions.

Contributors must not submit device-unique data, credentials, raw user data, or
additional firmware images without a separate publication review.
