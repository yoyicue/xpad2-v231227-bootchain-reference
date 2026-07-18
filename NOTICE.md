# Notice

The Git source tree intentionally excludes OEM preloader and LK binary images.
Following confirmed redistribution authorization, the `v231227-r2` GitHub Release
separately provides the unmodified `preloader_raw_a.img` and `lk_a.img` reference
images identified in `metadata/bootchain-hashes.tsv`.

The included SHA-256 values identify firmware observed on an owned TALIH-PD2 / XPad2
and are provided for interoperability, recovery research, and integrity checks.
The release assets remain OEM firmware and are not covered by this repository's
MIT license. No authorization is asserted for other firmware images.

The extraction tooling is read-only with respect to the Android device. It requires
root access that the device owner has already authorized and does not attempt to
obtain root, unlock the bootloader, bypass signature checks, or write partitions.

Contributors must not submit device-unique data, credentials, raw user data, or
additional proprietary firmware blobs without documented redistribution
authorization.
