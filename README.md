# XPad2 V231227 启动链参考资料

这是 TALIH-PD2 / XPad2 的 V231227 启动链研究资料库，面向同型号 ROM、恢复和
bootloader 研究。仓库公开脱敏元数据、已知镜像哈希、V231227 与观察到的
LS12 LK 样本之间的静态差异，以及从用户自己设备只读提取启动链镜像的工具。

## 适用范围

| 项目 | 值 |
| --- | --- |
| 产品 | TALIH-PD2 / XPad2 |
| 平台 | `ls12_mt8797_wifi_64` |
| SoC 家族 | MediaTek MT8797 |
| 旧固件 | V231227 / Android 13 |
| 旧内核 | `4.19.191+`，2023-12-27 构建 |
| 已确认中间版本 | V260523，incremental `239`，官方 OTA 与设备 A 槽交叉验证 |
| 受限 Fastboot 固件 | V260629，incremental `260`，官方 OTA 与设备 B 槽交叉验证 |
| 补充样本 | 2024-08-13 与 2024-12-16 构建的 LS12 LK，版本归属暂定 |

这些资料不能跨型号直接使用。即使 SoC 相同，DRAM、UFS、PMIC、显示面板、
签名链和分区布局也可能不同。

## 已确认的关键事实

- V231227 备份中有效的旧 LK 是 `lk_a.img`。
- V231227 的 `lk_b.img` 是完整的 8 MiB 全零镜像，不能作为 bootloader 使用。
- V231227 的 preloader raw A/B 镜像逐字节相同。
- 已确认的 V260629 B 槽 LK 仍保留 fastboot 初始化、`getvar:`、`download:`、
  `boot`、`continue`、`reboot-bootloader`、`reboot-fastboot` 和 `set_active:`。
- 该 V260629 LK 不再包含标准 `flash:`、`erase:` 命令字符串；这证明标准命令
  入口未注册，不代表所有底层存储写入辅助函数都被移除。
- 两份 2024 LS12 观察样本均保留标准 `flash:`、`erase:` 命令入口，但它们来自
  混合槽位整机备份，不能仅凭归档目录名认定为 V260213。
- 版本号已确认的 V260523 LK 也保留 `flash:`、`erase:`；官方 OTA 中的 LK
  补零到 8 MiB 后，与设备 A 槽实读镜像逐字节相同。
- 截至现有已确认样本，V260523 是最后一个仍保留这两个标准 Fastboot 命令
  入口的 LS12 版本；V260629 已确认不再包含它们。
- 因此目前只能把 LS12 标准写入/擦除入口的移除区间收窄到 V260523 至
  V260629 之间，不能笼统地称为“V260 全部阉割”。
- LK 分区大小和 A/B 布局未改变；变化发生在 LK 程序和签名内容中。

详细证据见 [LK 差异报告](reports/lk-v231227-vs-v260.md)。

## 已知哈希

| 镜像 | 字节 | SHA-256 | 说明 |
| --- | ---: | --- | --- |
| `preloader_raw_a.img` | 4,190,208 | `ee05973a30f3fd4a6f1ca344856784f96e7a6b630333ba25dc776205d3713f11` | V231227 |
| `preloader_raw_b.img` | 4,190,208 | `ee05973a30f3fd4a6f1ca344856784f96e7a6b630333ba25dc776205d3713f11` | 与 A 相同 |
| `lk_a.img` | 8,388,608 | `a87979a827c005107c68395c88396ce14a418dff0a23f89d473797e1476b3296` | V231227 有效旧 LK |
| `lk_b.img` | 8,388,608 | `2daeb1f36095b44b318410b3f4e8b5d989dcc7bb023d1426c492dab0a3053e74` | V231227 全零，禁止使用 |
| `lk_a-build-20240813-observed.img` | 8,388,608 | `ad8f5ea2b16efd60eb72045b35263b8c290dc5b151d75045e78b2af9a83434bf` | 疑似 V240813；观察样本 |
| `lk_b-build-20241216-observed.img` | 8,388,608 | `c87d7cd3903ceccd82a2fb6f4ac127434091ba0e4691d331511e35bb44654419` | V241216 时期；观察样本 |
| `preloader_raw_a-v260523.img` | 4,190,208 | `97cbf6d20e7e9cdffceb52a434bcb7ed5675c4eb055112ee90d2037374d3b54b` | V260523，版本号已确认 |
| `lk_a-v260523.img` | 8,388,608 | `6ebc4667ef9c0a6a888bda6d020cd744967e966c63b4d0ee6a07e5a21bce3b6a` | V260523，版本号已确认 |
| `preloader_raw_b-v260629.img` | 4,190,208 | `76e76d566b48d21387daabc7cbd2e972782995cebd4c07cd01cc5e3e823636f4` | V260629，版本号已确认 |
| `lk_b-v260629.img` | 8,388,608 | `4b5f932dee1d3d6f42a23a4f25c058fae7c7c14488b44d5df0959c6c7252f80e` | V260629，Fastboot 标准写入/擦除入口裁剪版 |

机器可读版本见 [bootchain-hashes.tsv](metadata/bootchain-hashes.tsv)。

## V231227 镜像下载

[`v231227-r2` Release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/v231227-r2)
提供以下两个附件：

| 附件 | 字节 | SHA-256 |
| --- | ---: | --- |
| [`preloader_raw_a.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/v231227-r2/preloader_raw_a.img) | 4,190,208 | `ee05973a30f3fd4a6f1ca344856784f96e7a6b630333ba25dc776205d3713f11` |
| [`lk_a.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/v231227-r2/lk_a.img) | 8,388,608 | `a87979a827c005107c68395c88396ce14a418dff0a23f89d473797e1476b3296` |

`preloader_raw_b.img` 与 A 逐字节相同，因而不重复发布；全零的 V231227
`lk_b.img` 不能使用，也不会发布。这里的 `preloader_raw_a.img` 是 mapper
读取所得的 4,190,208 字节 raw 镜像，不是 4,194,304 字节的 boot-LUN dump，
两种格式不能按文件名猜测或混用。

## V260523 启动链下载

[`ls12-lk-v260523-r1` Release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/ls12-lk-v260523-r1)
合并提供版本号已确认的 preloader 与 LK：

截至现有已确认样本，V260523 是最后一个仍保留 Fastboot `flash:`、`erase:`
命令入口的 LS12 版本；V260629 已确认移除这两个标准入口。

| 附件 | 字节 | SHA-256 |
| --- | ---: | --- |
| [`preloader_raw_a-v260523.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-lk-v260523-r1/preloader_raw_a-v260523.img) | 4,190,208 | `97cbf6d20e7e9cdffceb52a434bcb7ed5675c4eb055112ee90d2037374d3b54b` |
| [`lk_a-v260523.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-lk-v260523-r1/lk_a-v260523.img) | 8,388,608 | `6ebc4667ef9c0a6a888bda6d020cd744967e966c63b4d0ee6a07e5a21bce3b6a` |

版本证据来自 V260523 官方 A/B OTA（incremental `239`）和 LK 内部 Build ID
`ls12_mt8797_wifi_64-dfde152c-20241118095326-20260523165450`。OTA payload
中的原始 `lk.img` 为 1,261,568 字节，SHA-256 为
`9e987c2359982f0b2cabbf1e0fb756dd156d3af67f5cb8c423bad3fc9cd2139d`；按分区
格式补零到 8 MiB 后，与设备 A 槽实读镜像哈希完全一致。

OTA payload 中的 `preloader_raw.img` 为 495,616 字节，SHA-256 为
`cede4da9c9a4ec48914fa8eb321e686e6176617227c44df5fbe0d941c77e4aa7`；补零到
mapper raw 格式的 4,190,208 字节后，所得发布镜像同样与设备 A 槽实读哈希
完全一致。这里发布的是 mapper raw 形式，不是 4,194,304 字节 boot-LUN dump。

## V260629 受限 Fastboot 启动链下载

[`ls12-v260629-restricted-fastboot-r1` Release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/ls12-v260629-restricted-fastboot-r1)
提供版本号已确认的 V260629 preloader 与 LK：

这是本文所称的“裁剪版”：LK 仍保留 Fastboot 初始化、`getvar:`、`download:`、
`boot`、`continue`、重启和切槽等入口，但标准 `flash:`、`erase:` 命令注册入口
已经移除。这里的“裁剪”专指标准 Fastboot 写入/擦除命令面，不表示整个
Fastboot 或所有底层存储函数都已删除。

| 附件 | 字节 | SHA-256 |
| --- | ---: | --- |
| [`preloader_raw_b-v260629.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-v260629-restricted-fastboot-r1/preloader_raw_b-v260629.img) | 4,190,208 | `76e76d566b48d21387daabc7cbd2e972782995cebd4c07cd01cc5e3e823636f4` |
| [`lk_b-v260629.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-v260629-restricted-fastboot-r1/lk_b-v260629.img) | 8,388,608 | `4b5f932dee1d3d6f42a23a4f25c058fae7c7c14488b44d5df0959c6c7252f80e` |

版本证据来自 LS12 V260629 官方 A/B OTA（incremental `260`）、LK 内部 Build ID
`ls12_mt8797_wifi_64-405e7a01-20260602101307-20260629041106`，以及两台设备
B 槽实读。OTA 中 495,616 字节的 preloader 和 1,257,472 字节的 LK 分别补零
到 mapper raw / LK 分区大小后，均与设备实读哈希完全一致。preloader 附件是
4,190,208 字节 mapper raw 形式，不是 boot-LUN dump。

## LS12 2024 LK 观察样本

[`ls12-lk-2024-observed-r1` Release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/ls12-lk-2024-observed-r1)
提供两份来自同一混合槽位整机备份的 LK 观察样本：

| 附件 | 原分区名 | 内部构建日期 | 版本判断 |
| --- | --- | --- | --- |
| [`lk_a-build-20240813-observed.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-lk-2024-observed-r1/lk_a-build-20240813-observed.img) | `lk_a` | 2024-08-13 | 疑似 V240813，置信度中 |
| [`lk_b-build-20241216-observed.img`](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/download/ls12-lk-2024-observed-r1/lk_b-build-20241216-observed.img) | `lk_b` | 2024-12-16 | V241216 时期，置信度高 |

归档中的系统属性为 `ro.genie.gota.version=V241216`，并且 `lk_b`、`boot_b`、
`vendor_b` 的构建时间一致落在 2024-12-16；`lk_a` 只有内部 Build ID 支持
2024-08-13 这一时间点。该来源不是带 OTA metadata 的官方升级包，因此 Release
使用 `observed` 命名，不把疑似版本写成已经证实的固件归属。取得更多来源证据后，
可以更新标签和说明，镜像本身仍以 SHA-256 作为稳定身份。

## 从自己的设备提取

设备必须已经具有用户明确授权的 root 访问。工具只读取以下路径，不会写入
Android 分区：

```text
/dev/block/mapper/pl_a
/dev/block/mapper/pl_b
/dev/block/by-name/lk_a
/dev/block/by-name/lk_b
```

运行：

```sh
./tools/extract-own-device.sh ./my-xpad2-bootchain
./tools/classify-images.sh ./my-xpad2-bootchain
```

可通过 `ADB_SERIAL` 选择设备，通过 `SU_BIN` 指定设备端 `su`：

```sh
ADB_SERIAL=SERIAL SU_BIN=/system/bin/su \
  ./tools/extract-own-device.sh ./my-xpad2-bootchain
```

输出目录会包含镜像、设备端与本地端双重 SHA-256 以及不含序列号的元数据。
脚本遇到已有目标文件会停止，不会覆盖。

## 安全边界

本仓库不会接受或发布下列内容：

- `nvram`、`nvdata`、`proinfo`、`persist`
- `seccfg`、`efuse`、`otp`、`oempersist`
- userdata、系统状态归档、厂家日志
- 原始 GPT 镜像或未脱敏的磁盘/分区 GUID
- 设备序列号、MAC、校准数据或设备凭据

提交前运行：

```sh
./tools/publication-audit.sh
```

## 刷写警告

Preloader 和 LK 属于高风险启动链组件。不同主板或签名链上的镜像可能导致设备
在屏幕和 USB 初始化之前停止启动。锁定设备还可能在 preloader 阶段拒绝任何
被修改、重签错误或回滚受限的 LK。

本项目不提供刷写命令。任何恢复操作都应先验证精确型号、主板版本、分区大小、
启动槽、镜像哈希、签名状态和可恢复通道。即使文件校验正确，跨型号、跨主板或
错误写入 preloader 仍可能造成无法通过屏幕或 USB 恢复的硬砖。

## 许可与固件权利

仓库原创文档和工具采用 MIT 许可。各 Release 中的 OEM 镜像不适用 MIT
许可。其他 OEM 固件和设备唯一数据不在本次发布范围内。
