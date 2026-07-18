# LS12 incremental 1703659196 至 260 的 Preloader / LK 演变

## 结论

现有五组样本显示，LS12 启动链真正明确的功能收紧发生在 incremental `239`
之后、`260` 之时，而且 Preloader 与 LK 同时发生变化：

- Preloader 不再允许主机通过早期 USB/UART `FASTBOOT` 令牌把启动模式切换为
  Fastboot。
- LK 不再注册标准 Fastboot `flash:`、`erase:` 命令入口。

因此 V260629 的准确描述不是“完全删除 Fastboot”，而是同时限制了“如何进入”
和“进入后可以执行什么”。V260523 / incremental `239` 是当前最后一份确认仍同时
保留这两层入口的 LS12 样本。

本报告只做镜像结构、字符串和 ARM/Thumb 静态反汇编比较，没有执行刷写、擦除、
切槽或 bootloader patch。

## 样本身份

| incremental | 版本身份 | 版本证据 | LK 最终构建时间 |
| --- | --- | --- | --- |
| `1703659196` | V231227 | 旧版整机备份 | 2023-12-27 15:47:45 |
| `1723478295` | 2024-08-13 观察样本；高度疑似 V240813 | A 侧 boot/vbmeta 描述符与 LK Build ID | 2024-08-13 02:11:05 |
| `19` | V241216 | 当前系统属性、B 侧描述符与 LK Build ID | 2024-12-16 23:32:05 |
| `239` | V260523 | 官方 A/B OTA、设备 A 槽与 LK Build ID | 2026-05-23 16:54:50 |
| `260` | V260629 | 官方 A/B OTA、两台设备 B 槽与 LK Build ID | 2026-06-29 04:11:06 |

`1723478295` 的具体产品版本仍缺少 A 侧 `ro.genie.gota.version` 直接证据，因此
不能把“疑似 V240813”写成完全确认。

## 演变总览

| incremental | Preloader | LK |
| --- | --- | --- |
| `1703659196` | 支持早期 `FASTBOOT` 请求并回送 `TOOBTSAF` | 注册标准 `flash:`、`erase:` |
| `1723478295` | 早期 Fastboot 路径保留；认证/下载功能面不变 | 与前版几乎相同；标准写入/擦除入口保留 |
| `19` | 构建路径切换到 `V_origin_DAILY`；早期 Fastboot 路径保留 | 与前版几乎相同；标准写入/擦除入口保留 |
| `239` | 可执行主体与 `19` 相同；安全头字段及签名材料变化 | 与 `19` 使用同一源码修订标识；标准写入/擦除入口保留 |
| `260` | 识别 `FASTBOOT` 后明确拒绝，不再设置 Fastboot 启动模式 | 删除标准 `flash:`、`erase:` 注册入口，保留协议和底层存储能力 |

## Preloader

### 结构与认证连续性

五份 mapper raw 镜像均为 4,190,208 字节，GFH 给出的有效镜像长度均为
`0x78e4c`（495,180 字节），签名区长度均为 `0x66c`，签名边界均为
`0x787e0`。没有观察到容器布局或签名尺寸变化。

五版均保留下列静态功能面：

- SBC / secure boot 检查及证书、镜像认证日志。
- `usbdl_verify_da`、`usbdl_send_da`、`usbdl_jump_da` 等 DA 验证与下载路径。
- USB CDC ACM、UART、META / FACTORY 握手。
- 分区读取、写入、A/B、rollback 和 `seccfg` 相关路径。
- LK、ATF、TEE 等后续镜像加载和验证路径。

五份 preloader 均包含与 LK `cert1` 第一把 RSA-2048 公钥相同的 256 字节根
模数。该模数在不同构建中的代码区偏移会变化，但公钥内容没有轮换。

### `19` 至 `239`

两份 preloader 只有 548 个同偏移字节不同：

- GFH 类型 `BROM_SEC_CFG` 的 `customer_name` 尾部 4 字节从全零变为
  `33 e0 75 c9`（按小端整数为 `0xc975e033`）。
- 其余 544 个变化字节位于末端认证/签名记录。

从 `0x100` 开始的可执行代码逐字节相同。由于 GFH 字段位于签名覆盖范围内，
字段变化会自然导致摘要和 RSA 签名材料变化。现有公开定义只能把该位置归入
`customer_name`，不足以把这个 32 位值解释成防回滚版本、产品版本或某种开关。

### `239` 至 `260`：早期 Fastboot 入口被禁用

旧版 Preloader 的 BLDR 握手代码在收到 `FASTBOOT` 后执行：

```text
收到 "FASTBOOT"
  → 回送 "TOOBTSAF"
  → 将 boot_mode 写为 99
  → 返回已识别
```

V260629 对相同令牌改为：

```text
收到 "FASTBOOT"
  → 打印 "%s user version not supported"
  → 不回送 "TOOBTSAF"
  → 不再将 boot_mode 写为 99
  → 返回已识别
```

这不是仅凭字符串做出的推测：Thumb 反汇编同时确认了旧版的发送调用与
`boot_mode = 0x63` 写入，以及新版用日志调用替换该分支。

这里的 `user version` 是构建类型语境，不是 incremental 或 OTA 版本号。该分支
不能用来证明 BootROM 会拒绝旧版 preloader，也不能用来证明存在防降级检查。

这条路径只控制主机在 Preloader 握手阶段请求 Fastboot。按键组合、已保存的启动
模式或 Android `reboot bootloader` 是否经过同一分支，需要与具体进入方式分开
判断。

## LK

### 主 payload 演变

| incremental | data size | Build ID 源码标识 | 相对前一份的同偏移变化 |
| --- | ---: | --- | ---: |
| `1703659196` | `0xff018` | `7003d180` | 基线 |
| `1723478295` | `0xff018` | `45596c65` | 32 字节 / 0.003% |
| `19` | `0xff018` | `dfde152c` | 28 字节 / 0.003% |
| `239` | `0xff018` | `dfde152c` | 444 字节 / 0.043% |
| `260` | `0xfdd60` | `405e7a01` | payload 缩小 4,792 字节；发生重链接和代码变化 |

前四份 LK 的命令字符串偏移保持一致；变化主要是 Build ID、少量常量/指针、
调试字符串布局和每个镜像对应的认证材料。`19` 与 `239` 具有相同的源码修订标识
`dfde152c`，且没有观察到功能字符串增加或删除。因此可称为“同一功能基线的
不同构建”，但不能称为逐字节相同的可执行文件。

五份 LK 中独立封装的 `lk_main_dtb` 数据完全相同，其 SHA-256 均为：

```text
af3efe2d5bf158b83bbe31cb73f3123848d4784a1dc5df7f7e87eadaf4a80a91
```

### Fastboot 命令面

| 命令或能力 | `1703659196` | `1723478295` | `19` | `239` | `260` |
| --- | :---: | :---: | :---: | :---: | :---: |
| `fastboot_init` | 是 | 是 | 是 | 是 | 是 |
| `getvar:` | 是 | 是 | 是 | 是 | 是 |
| `download:` | 是 | 是 | 是 | 是 | 是 |
| `boot` / `continue` | 是 | 是 | 是 | 是 | 是 |
| 重启、切槽 | 是 | 是 | 是 | 是 | 是 |
| `flash:` | 是 | 是 | 是 | 是 | **否** |
| `erase:` | 是 | 是 | 是 | 是 | **否** |

旧版反汇编可以定位到 `flash:`、`erase:` 字符串被传给 Fastboot 注册函数的调用；
V260629 中相应字符串和两次注册调用均不存在。`download:` 仍然存在只表示主机可以
向 RAM 下载数据，不等于仍能把数据写入分区。

### 被裁掉的是对外入口，不是全部写入后端

V260629 仍包含：

```text
storage_write
storage_erase
partition_write
emmc_write
cmd_erase_mmc
稀疏镜像解析与写入错误路径
UFS / eMMC 底层写入和擦除路径
```

这些函数仍会被解锁、清理状态、内部启动流程或其他平台代码使用。V260629 甚至
仍保留下面的 Fastboot 帮助文本：

```text
flash xxpartid xxx.img
erase xxpartid
```

因此准确结论是“标准 Fastboot 写入/擦除命令入口被裁掉”，而不是“LK 已经没有
任何存储写入能力”。残留帮助文本也不能替代真正的命令注册。

## 密钥与签名连续性

五份 LK 主镜像的 `cert1` DER 完全相同：

```text
SHA-256 = 91e42388da7168ab01e695d2e696690ef2757e4edf26ea7216b584695ae021c5
```

五份 `cert2` 的证书内容会随镜像头、内容摘要和签名变化，但其中 RSA 公钥模数
相同；该公钥也与 `cert1` 授权的第二把公钥一致。结合五份 preloader 中相同的
根公钥模数，可以确认这次策略收紧没有伴随 LK 信任根或签名公钥轮换。

密钥连续性不表示可以修改或重签镜像。对 LK 代码或命令注册的任何修改仍会破坏
现有认证内容；是否允许刷入一份较旧但签名有效的镜像，还取决于设备写入权限、
分区选择及尚未完全确认的防回滚策略。

## 2025 样本缺口

缺少 2025 年的若干 dump，不影响当前裁剪窗口：

```text
V260523 / incremental 239：Preloader 早期 Fastboot 与 LK flash/erase 均保留
                              ↓ 37 天
V260629 / incremental 260：Preloader 拒绝早期 Fastboot，LK 删除 flash/erase
```

因此在当前产品线上，已确认的收紧发生在 2026-05-23 之后、2026-06-29 之时。
缺失样本仍意味着不能证明 2025 每一份内部或公开版本都完全相同，也不能排除某个
中间版本曾短暂改变后又恢复。所以文档使用“最后一份已确认样本”，不把 V260523
绝对化为未穷举全部版本后的“最后一版”。

## 充电界面现象

- 如果进入方式依赖向 Preloader 发送 `FASTBOOT` 令牌，V260629 的拒绝分支可以
  直接解释为什么设备没有切换到预期 Fastboot 模式。
- 如果使用 Android `adb reboot bootloader`、按键或其他已保存启动模式，则不应
  自动归因于这条握手分支。此时 LK 仍可能启动了受限 Fastboot，但显示仍停留在
  充电图或 USB gadget 没有正确枚举。

应以主机端 `fastboot devices` 和只读 `getvar` 响应判断协议是否实际存活，不能
只根据屏幕画面下结论。

## 参考

- [U-Boot MediaTek GFH 定义](https://github.com/u-boot/u-boot/blob/master/tools/mtk_image.h)
- [AOSP Fastboot protocol](https://android.googlesource.com/platform/system/core/+/master/fastboot/README.md)
