# XPad2 BootROM / Preloader 验证逻辑

更新日期：2026-07-19

适用范围：TALIH-PD2 / XPad2，基于 incremental `1703659196`、
`1723478295`、`19`、`239`、`260` 对应的 Preloader / LK 静态分析

## 结论

XPad2 的 preloader 使用“eFuse 根公钥哈希 + MediaTek GFH 头 + SHA-256
摘要 + RSA 签名/证书链”的 BootROM 验证模式。

如果芯片已经启用 SBC（Secure Boot Check），修改 preloader 任意受保护字节都会
改变摘要。修改后的镜像无法通过 BootROM 的签名验证，其中的代码也就没有机会
执行。

本文中 GFH、UFS 包装和第一组 LK 证书的精确偏移来自 V231227 镜像。两份
2024 LS12 观察样本、V260523 官方样本和正确的 LS12 V260629 官方/设备一致样本
已经完成结构、证书链和命令面交叉复核。五份样本使用相同的 LK 信任根与签名
公钥，但构建偏移和认证内容会变化，不能把某一版的全部精确偏移机械套到其他版本。
也不能把不同目录、构建日期或机型的样本统称为“V260”。

BootROM 只建立到 preloader 的第一段信任。V231227 preloader 内还带有验证后续
镜像的公钥和安全库；LK 不是由 BootROM 直接验证，而是在执行前由 preloader
验证。LK 自己再负责更后面的 boot、vbmeta 和 AVB 链路。

## 启动链

```text
芯片上电
  ↓
不可修改的 BootROM / BL1
  ↓ 读取 UFS Boot LUN
UFS_BOOT 头（4 KiB）
  ↓ 定位 0x1000 后的 preloader
解析 GFH FILE_INFO
  ↓
检查 eFuse SBC 状态和根公钥哈希
  ↓
验证证书链、SHA-256 和 RSA 签名
  ↓ 成功
加载到 SRAM，跳转执行 preloader
  ↓
preloader 再验证 LK、ATF、TEE 等后续阶段
  ↓
LK 执行 AVB，验证 vbmeta、boot 和系统分区
```

MediaTek 官方资料说明，BootROM 是硬件 Root of Trust。启用 SBC 后，BootROM
将镜像内根公钥的 SHA-256 与 eFuse 中烧录的公钥哈希比较，然后验证加载器摘要
和 RSA 签名：

- [MediaTek Secure Boot 文档](https://genio.mediatek.com/doc/iot-yocto/latest/sw/yocto/secure-boot.html)

官方文档以 Genio 平台的 BL2 为例；在 XPad2 Android 启动链中，对应的第二阶段
是 MediaTek preloader。具体镜像结构以下面的 XPad2 实测结果为准。

## UFS Boot LUN 与 raw 镜像

V231227 的 `preloader_a_lun.img` 布局为：

```text
0x000000 ─ 0x000fff   UFS_BOOT 包装头
0x001000 ─ 末尾       preloader_raw_a.img
```

已经逐字节确认：

```text
preloader_a_lun.img[0x1000:] == preloader_raw_a.img
```

因此公开的 `preloader_raw_a.img` 是 GFH 开头的内部镜像，不包含 4 KiB
`UFS_BOOT` 包装头，不能当作完整 Boot LUN 镜像直接使用。

本次授权备份中的对应文件名：

- `preloader_a_lun.img`
- `preloader_raw_a.img`

## V231227 GFH 实测字段

raw 镜像从 MediaTek GFH `FILE_INFO` 开始：

| 字段 | 值 |
| --- | ---: |
| GFH magic | `MMM\x01` / `FILE_INFO` |
| Load address | `0x00200f00` |
| Content offset | `0x100` |
| Jump offset | `0x100` |
| 实际入口地址 | `0x00201000` |
| Total size | `0x78e4c`，495,180 字节 |
| Signature size | `0x66c`，1,644 字节 |
| 签名区起点 | `0x787e0` |
| 最大镜像大小 | `0x80000` |

GFH 的核心字段与公开的 MediaTek BootROM 头定义一致：

- [U-Boot MediaTek GFH 定义](https://github.com/u-boot/u-boot/blob/master/tools/mtk_image.h#L83-L166)

不过 XPad2 使用了较新的 proprietary 字段值，例如 `flash_type=0x0c`、
`sig_type=0x05`，并包含额外的 GFH 类型 `0x12`。公开 U-Boot 定义不能完整解释
这份 SV5 风格镜像的所有字段。

## 五版本 Preloader 功能演变

### 样本身份

| incremental | 版本身份 | Preloader SHA-256 | 早期 `FASTBOOT` 握手 |
| --- | --- | --- | --- |
| `1703659196` | V231227 | `ee05973a30f3fd4a6f1ca344856784f96e7a6b630333ba25dc776205d3713f11` | 接受并回送 `TOOBTSAF` |
| `1723478295` | 2024-08-13 A 槽观察样本；高度疑似 V240813 | `1344b6221fcb6eefbca725195cbd708b54ef15b779c5e9b508096dfea2d54c3f` | 接受并回送 `TOOBTSAF` |
| `19` | V241216 B 槽 | `548fd2f6b16d64ca3eaae9f69128bade545ce35838880b3b12e00645639f1d74` | 接受并回送 `TOOBTSAF` |
| `239` | V260523 | `97cbf6d20e7e9cdffceb52a434bcb7ed5675c4eb055112ee90d2037374d3b54b` | 接受并回送 `TOOBTSAF` |
| `260` | V260629 | `76e76d566b48d21387daabc7cbd2e972782995cebd4c07cd01cc5e3e823636f4` | 明确拒绝，不再回送 ACK |

`1723478295` 与 `19` 的版本关联来自同一混合槽位 dump 的 A/B 描述符和 LK Build
ID。前者仍缺少 A 侧 `ro.genie.gota.version=V240813` 的直接证据，因此继续使用
“高度疑似”而不是确认版本名。

五份 mapper raw 镜像大小均为 4,190,208 字节；GFH 有效长度均为 `0x78e4c`，
签名长度均为 `0x66c`，签名边界均为 `0x787e0`。五版均保留 SBC、镜像认证、
DA 验证/发送/跳转、USB CDC ACM、UART、META/FACTORY、分区读写、A/B 和
rollback 相关路径。因此没有证据表明 V260629 删除了 Preloader 的整个下载或
认证子系统。

### `19 → 239`：代码不变，安全头与签名变化

这两份 preloader 只有 548 个同偏移字节不同：

- GFH 类型 `BROM_SEC_CFG` 的 `customer_name` 尾部 4 字节，从全零变为
  `33 e0 75 c9`（小端为 `0xc975e033`）。
- 其余 544 个变化字节位于末端认证/签名记录。

从 `0x100` 开始的可执行代码逐字节相同。这个 GFH 字段位于签名覆盖范围内，
因而会引起摘要和 RSA 签名材料变化。当前不能把该 32 位值命名为产品版本、
防回滚版本或功能开关。

### `239 → 260`：主机请求的早期 Fastboot 被禁用

Preloader 的 `FASTBOOT` 字符串属于 BLDR 阶段的 USB/UART 文本握手，不是进入
LK 之后的 Fastboot 命令协议。旧版分支在匹配该令牌后：

```text
发送 "TOOBTSAF"
boot_mode = 99
返回“已识别”
```

V260629 的同一分支改为：

```text
打印 "%s user version not supported"
不发送 "TOOBTSAF"
不再写入 boot_mode = 99
返回“已识别”
```

Thumb 反汇编同时确认了旧版的发送调用和 `0x63` 写入，以及新版用日志调用替换
该路径。因此 V260629 确实裁掉了“主机在 Preloader 握手阶段请求 Fastboot”这一
入口。这里的 `user version` 指 user 构建语境，不是 OTA/incremental 版本，不能
据此推导 BootROM 防降级逻辑。

按键、Android `reboot bootloader` 或已保存启动模式是否经过这条分支，应与进入
方式分开判断；不能把所有 Fastboot 进入失败都归因于这一个握手分支。

## SHA-256 覆盖范围

GFH 给出的签名边界为：

```text
0x78e4c - 0x66c = 0x787e0
```

对签名区之前的全部字节计算 SHA-256：

```text
SHA256(preloader_raw_a.img[0:0x787e0])
= 40cc669a852740e309e1a40c1b4bc0f38300776691ba23dfd1b94bca3e76a4b8
```

这个摘要与镜像签名记录 `0x78d2c` 位置的 32 字节完全一致。因此至少可以确认：

- GFH 和代码主体都在摘要覆盖范围内。
- 修改 `0x000000` 至 `0x787dff` 之间的任意字节都会改变摘要。
- 签名/证书容器位于 `0x787e0` 至 `0x78e4b`。

复核命令：

```sh
dd if=preloader_raw_a.img bs=1 count=$((0x787e0)) status=none \
  | shasum -a 256
```

## RSA 与证书容器

签名区具有以下结构特征：

- 开头值为 `2`，后面两项长度分别是 `0x52c` 和 `0x13c`。
- 两项长度与外层 `0x66c` 签名区严丝合缝。
- 证书记录中存在 RSA 公钥指数 `0x10001`，即 65537。
- 最终 SHA-256 摘要后紧跟 256 字节签名。

256 字节 RSA 签名对应 2048 位模数，所以这份 V231227 preloader 可以确认采用
RSA-2048 尺寸的签名结构，并使用 SHA-256 摘要。

当前尚未完整解码 proprietary 证书字段，因此不能仅凭现有证据断言签名填充是
PKCS#1 v1.5 还是 RSA-PSS。

## BootROM 验证逻辑

结合 MediaTek 官方流程、GFH 字段和 XPad2 镜像证据，可以还原为：

```c
read_efuse(&sbc_enabled, fused_root_key_hash);

read_ufs_boot_header();
read_gfh_file_info();

validate_gfh_bounds();
load_image_and_signature();

if (sbc_enabled) {
    root_key = certificate_chain.root_key;

    if (sha256(root_key) != fused_root_key_hash)
        reject();

    if (!verify_certificate_chain(certificate_chain))
        reject();

    digest = sha256(image[0:signature_offset]);

    if (digest != signed_digest)
        reject();

    if (!rsa_verify(signing_key, signed_digest, rsa_signature))
        reject();
}

copy_to_sram(load_address);
jump(load_address + jump_offset);
```

验证失败后，BootROM 不会跳转执行这份 preloader。失败后究竟尝试另一个 Boot
LUN、停机还是进入受限 BROM USB 模式，取决于具体 BootROM、eFuse 和
`BROM_CFG`，目前没有 XPad2 的失败启动日志，不能确定其精确分支。

## Preloader 验证 LK 的逻辑

### V231227 LK 镜像结构

分析对象：

```text
文件：lk_a.img
大小：8,388,608 字节
SHA-256：a87979a827c005107c68395c88396ce14a418dff0a23f89d473797e1476b3296
```

文件开头是 MediaTek 分区镜像头，代码从 `0x200` 开始：

| 字段 | 值 |
| --- | ---: |
| 分区头 magic | `0x58881688` |
| data size | `0x000ff018` |
| image name | `lk` |
| 扩展头 magic | `0x58891689` |
| header size | `0x200` |
| header version | `1` |
| LK 数据范围 | `0x000200` 至 `0x0ff217` |

LK 数据后面紧跟两个名为 `cert1`、`cert2` 的 MediaTek 证书容器：

| 容器 | 镜像头偏移 | DER 数据偏移 | DER 长度 |
| --- | ---: | ---: | ---: |
| `cert1` | `0x0ff220` | `0x0ff420` | `0x6c5` |
| `cert2` | `0x0ffaf0` | `0x0ffcf0` | `0x3d6` |

这里的 DER 不是普通 Web PKI X.509 证书：它保留了 X.509 风格的主体、公钥和
签名算法结构，但加入了 MediaTek 私有 OID 和字段。因此通用 `openssl x509`
不能完整解释它，`openssl asn1parse` 可以解析其 ASN.1 层级。

### 证书链实测

V231227 镜像可以确认以下关系：

```text
preloader 内嵌 RSA 根公钥
  │  与 cert1 第一把 RSA 公钥的 256 字节模数完全一致
  ↓
cert1
  │  自身外层签名：RSA-PSS + SHA-256，salt 32 字节
  │  同时授权第二把 RSA-2048 公钥
  ↓
cert2
  │  公钥与 cert1 授权的第二把公钥完全一致
  │  外层签名：RSA-PSS + SHA-256，salt 32 字节
  ↓
LK 镜像头和镜像认证字段
```

具体复核结果：

- `cert1` 第一把 RSA 公钥的模数与 preloader 文件偏移 `0x5a5c8` 处的 256
  字节完全相同。
- 用这把根公钥验证 `cert1` 外层签名，结果为 `Verified OK`。
- `cert1` 中授权的第二个 SPKI 与 `cert2` 的 SPKI 逐字节相同。
- 用第二把公钥验证 `cert2` 外层签名，结果为 `Verified OK`。
- 两个证书的签名算法参数均明确指定 RSA-PSS、SHA-256、MGF1-SHA-256 和
  32 字节 salt。
- `cert2` 私有 OID `2.16.886.2454.2.4` 中的 32 字节值为：

  ```text
  dd40d5064dfce59a9604f8cf9c6c385d18a1eec1eb3988ca5761c380e43e834f
  ```

  它与 `SHA256(lk_a.img[0:0x200])` 完全一致，证明 LK 的 512 字节 MediaTek
  镜像头受证书字段约束。

`cert2` 还含有另一个 32 字节私有字段
`2.16.886.2454.2.1`。preloader 的认证代码会计算并输出
`imghdr + image` 的摘要，但在缺少 MediaTek 私有证书格式定义的情况下，暂时
不把这个字段强行命名为某一种摘要，也不对其精确覆盖范围作未经验证的断言。

### LS12 跨版本与观察样本复核

当前用于纵向比较的五份 LS12 LK 样本如下。两份 2024 样本来自一个混合槽位整机
备份，归档目录名不能作为版本证据；V260523 与 V260629 均由官方 OTA 和设备槽位
实读交叉确认：

| 样本身份 | LK SHA-256 | data size | 版本证据 |
| --- | --- | ---: | --- |
| V231227 `lk_a` | `a87979a827c005107c68395c88396ce14a418dff0a23f89d473797e1476b3296` | `0xff018` | 旧版整机备份与内部 Build ID |
| 2024-08-13 `lk_a` 观察样本 | `ad8f5ea2b16efd60eb72045b35263b8c290dc5b151d75045e78b2af9a83434bf` | `0xff018` | 内部 Build ID；疑似 V240813，置信度中 |
| 2024-12-16 `lk_b` 观察样本 | `c87d7cd3903ceccd82a2fb6f4ac127434091ba0e4691d331511e35bb44654419` | `0xff018` | 内部 Build ID 与配套 system/boot/vendor；V241216 时期，置信度高 |
| V260523 `lk_a` | `6ebc4667ef9c0a6a888bda6d020cd744967e966c63b4d0ee6a07e5a21bce3b6a` | `0xff018` | 官方 OTA incremental `239`、设备 A 槽与内部 Build ID |
| V260629 设备实读 `lk_b` | `4b5f932dee1d3d6f42a23a4f25c058fae7c7c14488b44d5df0959c6c7252f80e` | `0xfdd60` | `ro.genie.gota.version=V260629`、活动槽 `_b`、内部 2026-06-29 Build ID |

其中 2024-12-16 观察样本所在备份的 `system_a` 明确报告
`ro.genie.gota.version=V241216`；`lk_b`、`boot_b` 和 `vendor_b` 的构建时间也都
落在 2024-12-16。2024-08-13 样本只有 LK 内部 Build ID 支持该日期，不能写成
已经证实的 V240813 固件。

对这五份 LS12 样本，可以确认：

- 五份 LK 主镜像的 `cert1` DER 完全相同，其 SHA-256 均为
  `91e42388da7168ab01e695d2e696690ef2757e4edf26ea7216b584695ae021c5`。
- 五份配套 preloader 所内嵌 256 字节 LK 根 RSA 模数均与该 `cert1` 根公钥
  一致；不同构建中的文件偏移会变化，公钥内容没有轮换。
- `cert1` 授权的第二把公钥和五份 `cert2` 公钥保持一致；`cert2` 内容本身会随
  镜像头、内容认证字段和签名变化。
- 各样本 `cert2` 的 `2.16.886.2454.2.4` 都与各自 512 字节 LK 头的 SHA-256
  完全一致。
- `2.16.886.2454.2.1` 随 LK 内容变化，但它不等于直接计算得到的
  `SHA256(payload)` 或 `SHA256(header + payload)`。这证明该字段与版本内容
  相关，但还不足以确定它的算法和覆盖范围。
- 五份 LK 中独立封装的 `lk_main_dtb` 逐字节相同，其 SHA-256 均为
  `af3efe2d5bf158b83bbe31cb73f3123848d4784a1dc5df7f7e87eadaf4a80a91`。

Fastboot 命令面可以独立确认：V231227、两份 2024 LS12 观察样本和 V260523 均
保留 `flash:`、`erase:`、`download:`、`getvar:` 及对应注册调用；V260629
`lk_b` 保留 Fastboot 初始化及查询/控制命令，但没有标准 `flash:`、`erase:`
字符串和注册调用。因此准确表述是“incremental `239` 是当前最后一份确认仍保留
标准 Fastboot 写入/擦除入口的样本，`260` 已裁掉该命令面”，而不是笼统地称
“V260 全部被裁剪”。

V260629 仍包含 `storage_write`、`storage_erase`、`partition_write`、
`emmc_write`、`cmd_erase_mmc`、稀疏镜像解析以及 UFS/eMMC 底层写擦路径，甚至
保留 `flash xxpartid xxx.img`、`erase xxpartid` 帮助文本。被移除的是标准
Fastboot 对外命令入口，不是 LK 的全部存储写入能力。

V260629 进入 Fastboot 时停留在充电界面，需要按进入方式区分：如果工具依赖
Preloader `FASTBOOT` 文本握手，新版拒绝分支可直接阻止模式切换；如果使用
`adb reboot bootloader`、按键或已保存启动模式，则仍可能涉及 LK 启动模式传递、
USB gadget 初始化或显示/充电状态机。标准写入命令缺失不能单独证明协议层没有
启动；需要以 `fastboot devices` 和只读 `getvar` 的现场响应区分。

V260523 构建于 2026-05-23，V260629 构建于 2026-06-29，因此两层 Fastboot
限制的已确认引入窗口为 37 天。缺少 2025 年的若干 dump 不影响这一窗口，因为
incremental `239` 已经晚于 2025 年且仍保留旧功能；但这仍不足以证明 2025 每个
内部或公开版本都完全相同。

### 跨机型附注：LS14 / build 262

此前误写为 LS12 V260629 的下列镜像，实际来自旁边完整包的 metadata：

```text
pre-device=ls14_mt8797_wifi_64
post-build-incremental=262
```

| 机型与样本 | LK SHA-256 | data size |
| --- | --- | ---: |
| LS14 / build 262 `lk` | `779cd911f470b9b18c821e787c9db9218a344841a77b13e235ec9d6343d9ecb5` | `0x10cef4` |

该 LS14 LK 独立静态复核时也显示相同 `cert1`，并缺少标准 `flash:`、`erase:`
命令入口；这只能说明跨产品存在密钥或策略复用，不能作为 LS12 V260629 的证书链、
payload 或功能证据。

### Preloader 中的执行证据

V231227 preloader 本身包含以下分区名和日志：

```text
lk_a
lk_b
lk partition not found
cert chain vfy fail...
Verification Pass
Verification Fail
cert img_hdr_type = 0x%x
cert verify, part = %s, img = %s...
img auth fail
img auth ok
dump (imghdr + image) hash...
sbc_en = %d
Second Bootloader Load Failed
```

相关源码路径字符串分别指向 preloader 的 `core/main.c`、`core/partition.c`、
`security/auth/sec_auth.c` 和 `secure_lib`。这说明分区选择、镜像读取、证书链
校验和镜像认证都在 preloader 阶段发生，而不是由 LK 自己对自己验证。

结合镜像结构和签名实测，验证流程可以还原为：

```c
slot = get_active_slot();
part = find_partition(slot == A ? "lk_a" : "lk_b");

read_mtk_image_header(part, &hdr);
if (hdr.magic != 0x58881688 || !bounds_are_valid(hdr))
    fail_second_bootloader();

policy = get_secure_boot_policy();
if (policy.requires_auth) {
    read_cert1_and_cert2(part, hdr.data_size);

    if (!same_trusted_key(cert1.root_key, preloader_embedded_key))
        fail_second_bootloader();

    if (!verify_rsa_pss_sha256(cert1, cert1.root_key))
        fail_second_bootloader();

    if (!cert1_authorizes(cert2.public_key))
        fail_second_bootloader();

    if (!verify_rsa_pss_sha256(cert2, cert2.public_key))
        fail_second_bootloader();

    hashes = hash_image_header_and_image(hdr, image);
    if (!certificate_fields_match(hashes, part.name, hdr.type))
        fail_second_bootloader();
}

load_lk();
jump_to_lk();
```

这段伪代码表达的是已经确认的验证层次，不代表 proprietary 函数的逐条反编译。
其中槽位选择、失败后是否尝试另一槽，以及防回滚字段的具体判定顺序仍需启动日志
或更完整的控制流分析确认。

### 对 patch 和降级的直接影响

- 修改 LK 的 512 字节镜像头会使已确认的 SHA-256 字段不再匹配。
- preloader 日志和随版本变化的 `2.16.886.2454.2.1` 字段都表明 LK 正文进入
  镜像认证路径。现阶段应假定修改代码或资源会使认证失败，但在私有摘要算法和
  覆盖范围完全解出前，不把“每个正文字节必然受保护”写成已经逐字节证明的事实。
- 如果修改确实落在正文认证覆盖范围内，没有对应私钥就不能重新生成能通过原
  证书链的签名。
- Fastboot 解锁和 AVB orange 状态发生在 LK/Android Verified Boot 层，通常
  不会自动关闭 preloader 对 LK 的认证。
- 未修改的旧版 LK 保留完整 OEM 证书链，因此从密码学角度比 patch LK 更可行；
  但仍要满足同一根密钥、镜像类型、分区策略和可能存在的防回滚条件。

preloader 认证失败时可以确认不会正常跳入该 LK。镜像中虽有
`Second Bootloader Load Failed` 和 `PL fatal error`，但目前还不能仅凭字符串
断言 XPad2 一定会尝试另一槽，或一定停在哪个画面。

## XPad2 内核中的 SBC 状态传递

XPad2 的 MediaTek 安全驱动从设备树 `/chosen/atag,masp` 接收：

- `rom_info_sbc_attr`
- `rom_info_sdl_attr`
- `hw_sbcen`
- `lock_state`
- 32 字节 `sbc_pubk_hash`

本次核对使用的 TALIH-PD2 Linux 4.19.191 源码位置如下；源码本身不随本仓库
发布：

- `drivers/misc/mediatek/masp/asfv2/module/sec_mod.h`：`masp_tag` 结构，约第 45 行。
- `drivers/misc/mediatek/masp/asfv2/module/sec_mod.c`：`atag,masp` 读取逻辑，约第 331 行。
- `drivers/misc/mediatek/masp/asfv2/core/sec_boot_core.c`：Secure Boot 判断逻辑，约第 98 行。

内核判断规则为：

- `rom_info_sbc_attr == 0x11`：强制启用 secure boot。
- 常规配置：由硬件 `hw_sbcen` 决定。
- 安全芯片上的 secure boot 不能由普通软件关闭。

目前尚未从这台设备读取实际的 `rom_info_sbc_attr` 和 `hw_sbcen`。此前观察到的
`locked/green` 属于后续 AVB 状态，`ro.boot.efuse=1` 也不能单独作为 BootROM
SBC 已启用的最终证据。

设备重新连接后，可以只读 `/chosen/atag,masp` 的前 24 字节确认 SBC 状态，
无需刷写、重启或读取后面的设备 RID、crypto seed。

## 与其他验证机制的区别

### SBC

SBC 是 BootROM 对存储中 preloader 的验证。根信任来自芯片 eFuse。

### DAA / SLA

DAA 是 BootROM 对 USB Download Agent 的认证；SLA 是下载会话授权。它们影响
BROM USB 下载通道，不等同于存储中 preloader 的 SBC 验证。

### Preloader 对 LK 的验证

BootROM 通常不直接验证 LK。BootROM 验证并运行 preloader，然后由 preloader
中的安全库验证 LK、ATF、TEE 等后续镜像。V231227 LK 的证书链、算法和
preloader 内嵌根公钥的对应关系见上面的“Preloader 验证 LK 的逻辑”。

preloader 内出现的 `sbc_en`、`cert verify` 等字符串主要描述它对后续阶段的
安全检查，不能单独证明 BootROM 是否启用了对 preloader 自身的 SBC。

### AVB 和 Fastboot 解锁

AVB、`locked/green` 和 Fastboot 解锁属于更后面的 LK/Android Verified Boot
层。Fastboot 解锁不会修改 BootROM，也不会清除已经烧入 eFuse 的 SBC 根信任。

- [AOSP Bootloader 概览](https://source.android.com/docs/core/architecture/bootloader)

## 对当前刷写与研究方案的影响

1. **Patch preloader**

   如果 SBC 已启用，修改代码、GFH 或受保护数据都会破坏 SHA-256 和 RSA
   签名。尝试在 preloader 内 patch `sbc_en` 没有意义，因为 BootROM 会在这些
   代码执行之前拒绝镜像。

2. **使用原始 OEM 签名的旧版 preloader**

   未经修改的旧版镜像保留原始签名，只要根签名链相同并且没有额外回滚限制，
   密码学上比 patch preloader 更可行。但不能仅凭“签名有效”断言一定允许降级。

3. **Patch LK**

   LK 不是由 BootROM 直接验证，而是由 preloader 验证。其补丁可行性取决于
   preloader 的证书策略和 LK 签名链，仍不能简单绕过。

4. **镜像格式**

   `preloader_raw_a.img` 与完整 `preloader_a_lun.img` 相差 4 KiB UFS 包装头。
   文件名不能代替对目标设备、写入接口和偏移的确认，二者不可混用。

## 当前证据边界

已经确认：

- V231227 UFS 包装头和 raw preloader 的精确关系。
- GFH 关键字段、加载地址、入口地址和签名边界。
- SHA-256 覆盖范围及镜像内存储摘要的一致性。
- RSA-2048 尺寸、指数 65537 和两段式证书/签名容器。
- XPad2 内核接收 SBC eFuse 状态和 32 字节公钥哈希的代码路径。
- V231227 preloader 内嵌的 LK 根公钥与 `cert1` 根公钥一致。
- V231227 LK 的 `cert1 → cert2` 授权关系和两层 RSA-PSS/SHA-256 签名。
- LK 512 字节镜像头 SHA-256 与 `cert2` 私有字段完全一致。
- 五份 LS12 样本使用同一份 LK 主镜像 `cert1`、同一 LK 根公钥和同一把被授权的
  `cert2` 公钥；正确的 V260523、V260629 样本均已纳入复核。
- 五份 LK 中独立封装的 `lk_main_dtb` 逐字节相同。
- V231227、两份 2024 LS12 观察样本和 V260523 均保留标准 `flash:`、`erase:`；
  V260629 `lk_b` 缺少这两个字符串和对应注册调用，但仍保留底层写擦后端。
- incremental `19` 与 `239` 的 preloader 可执行代码相同；变化仅在一个 GFH
  安全配置字段及签名材料。
- V260629 preloader 识别早期 `FASTBOOT` 令牌后明确报告 user build 不支持，
  不再回送 `TOOBTSAF`，也不再写入 Fastboot boot mode 99。
- 两层 Fastboot 收紧都可以定位到 incremental `239` 之后、`260` 之时。
- SHA-256 为 `779cd911...` 的样本属于 LS14 / build 262，不属于 XPad2/LS12。

尚未确认：

- 当前设备实际的 `hw_sbcen` 和 `rom_info_sbc_attr` 值。
- preloader 自身 proprietary 证书字段的完整定义和 RSA padding 类型。
- BootROM 验证失败后的 XPad2 精确回退顺序。
- BootROM 是否对该版本 preloader 另外执行防回滚检查。
- LK 镜像正文摘要对应的私有 OID、精确覆盖范围及防回滚字段语义。
- V260523/V260629 preloader 中 `BROM_SEC_CFG.customer_name` 尾部
  `0xc975e033` 的精确语义。
- LS12 V260629 preloader 除已确认的早期 Fastboot 拒绝分支外，认证和下载控制流
  是否还有无法从字符串与当前反汇编覆盖范围识别的策略差异。
- LK 认证失败后是否回退另一槽，以及 XPad2 的精确失败界面。
