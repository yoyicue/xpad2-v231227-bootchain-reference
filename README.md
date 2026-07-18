# XPad2 V231227 启动链参考资料

这是 TALIH-PD2 / XPad2 的 V231227 启动链研究资料库，面向同型号 ROM、恢复和
bootloader 研究。仓库公开脱敏元数据、已知镜像哈希、V231227 与 V260 LK 的
静态差异，以及从用户自己设备只读提取启动链镜像的工具。

仓库不分发厂商 proprietary 固件二进制，也不包含自动刷写功能。

## 适用范围

| 项目 | 值 |
| --- | --- |
| 产品 | TALIH-PD2 / XPad2 |
| 平台 | `ls12_mt8797_wifi_64` |
| SoC 家族 | MediaTek MT8797 |
| 旧固件 | V231227 / Android 13 |
| 旧内核 | `4.19.191+`，2023-12-27 构建 |
| 对比固件 | V260629，incremental `260` |

这些资料不能跨型号直接使用。即使 SoC 相同，DRAM、UFS、PMIC、显示面板、
签名链和分区布局也可能不同。

## 已确认的关键事实

- V231227 备份中有效的旧 LK 是 `lk_a.img`。
- V231227 的 `lk_b.img` 是完整的 8 MiB 全零镜像，不能作为 bootloader 使用。
- V231227 的 preloader raw A/B 镜像逐字节相同。
- 当前观察到的 V260 LK 仍保留 fastboot 初始化、`getvar:`、`download:`、
  `boot`、`continue`、`reboot-bootloader`、`reboot-fastboot` 和 `set_active:`。
- V260 LK 不再包含标准 `flash:`、`erase:` 命令字符串及旧写入后端标记。
- LK 分区大小和 A/B 布局未改变；变化发生在 LK 程序和签名内容中。

详细证据见 [LK 差异报告](reports/lk-v231227-vs-v260.md)。

## 已知哈希

| 镜像 | 字节 | SHA-256 | 说明 |
| --- | ---: | --- | --- |
| `preloader_raw_a.img` | 4,190,208 | `ee05973a30f3fd4a6f1ca344856784f96e7a6b630333ba25dc776205d3713f11` | V231227 |
| `preloader_raw_b.img` | 4,190,208 | `ee05973a30f3fd4a6f1ca344856784f96e7a6b630333ba25dc776205d3713f11` | 与 A 相同 |
| `lk_a.img` | 8,388,608 | `a87979a827c005107c68395c88396ce14a418dff0a23f89d473797e1476b3296` | V231227 有效旧 LK |
| `lk_b.img` | 8,388,608 | `2daeb1f36095b44b318410b3f4e8b5d989dcc7bb023d1426c492dab0a3053e74` | V231227 全零，禁止使用 |
| `lk_b-v260.img` | 8,388,608 | `4b5f932dee1d3d6f42a23a4f25c058fae7c7c14488b44d5df0959c6c7252f80e` | V260 对比哈希，不分发镜像 |

机器可读版本见 [bootchain-hashes.tsv](metadata/bootchain-hashes.tsv)。

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

本仓库只提供研究和只读提取资料，不提供刷写命令。任何恢复操作都应先验证
精确型号、分区大小、启动槽、镜像哈希、签名状态和可恢复通道。

## 许可与固件权利

仓库原创文档和工具采用 MIT 许可。表中哈希仅用于识别和验证 OEM 固件；OEM
固件及其商标、代码和签名材料仍归各自权利人所有。请只从自己有权访问的设备
或官方固件中提取镜像。
