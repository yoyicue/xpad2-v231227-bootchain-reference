# XPad2 LS12：降级 LK 恢复 Fastboot——已验证方法、复现步骤与安全边界

> - 文档状态：2026-07-20 发布稿
> - 适用设备：TALIH-PD2 / XPad2，平台 `ls12_mt8797_wifi_64`
> - 不适用：LS14 / build 262，以及其他 MT8797 机型
> - 风险等级：高。下文包含启动链分区写入操作；写错槽位、镜像或分区可能导致设备无法启动。
> - 文档性质：互操作与恢复研究记录；包含明确标注的手工验证命令，不提供自动刷写工具。

## 1. 结论与适用范围

“降级 LK 恢复 Fastboot”已经有真机成功案例，不只是静态分析得出的设想。现有社区实测教程是成功操作后的复盘总结：参与者获得临时 root，将旧版 LK 写回设备，再通过 Android Utility/AUP 的 `Reboot Fastboot mode` 进入 LK Fastboot，最终执行了解锁。

这套方法的原理是：把仍注册标准 Fastboot `flash:`、`erase:` 命令的旧版、原厂签名 LK，写入设备下一次会加载的 `lk_a` 或 `lk_b`。它恢复的是 **LK 运行后的 Fastboot 命令面**，不会修改 BootROM，也不会绕过 Preloader 对 LK 的认证。

对当前 V260629 样机，建议研究的组合是：

```text
保留：V260629 Preloader
替换：V260629 LK → V260523 / incremental 239 LK
保持：V260629 Android
```

核心结论如下：

- 社区成功案例已经证明“旧 LK + AUP”能够恢复 Fastboot 并完成解锁；
- V260523 / incremental `239` 是当前最后一份确认保留标准 `flash:`、`erase:` 入口的 LS12 LK；
- 当前活动槽为 B 时，实际写入目标是 `/dev/block/by-name/lk_b`，不是教程中的 `/dev/block/by-name/lk`；
- 当前机器的 BROM 不支持 Preloader 降级，因此只研究 LK，不回写旧 Preloader；
- 进入 Fastboot 与解除设备锁是两个步骤：旧 LK 可以恢复命令面，但标准 `fastboot flashing unlock` 仍可能受 OEM 策略限制；
- V260629 Preloader 中观察到的早期 `FASTBOOT` 拒绝分支，是当前精确组合的动态核查点，不是对社区成功案例的反证。

本文使用以下证据强度：

| 标记         | 含义                                                   |
| ------------ | ------------------------------------------------------ |
| **已确认**   | 镜像哈希、版本、静态反汇编或当前设备只读结果可重复验证 |
| **成功案例** | 社区教程作者和参与者报告真机进入 Fastboot 并完成解锁   |
| **合理推断** | 启动链逻辑和样本连续性支持，但当前精确组合尚未直连闭环 |
| **待验证**   | 不能作为批量操作或救砖保证                             |

## 2. 社区实测教程验证的方法

### 2.1 成功过程

现有社区实测教程记录了以下操作链：

1. 设备获得临时 root，并开启 OEM 解锁开关；
2. 备份当前 LK；
3. 用 `dd` 写入一份旧版 LK；
4. 关机连接 Windows，在 AUP/Bypass 中执行 `Reboot Fastboot mode`；
5. AUP 日志出现 `CMD_BootAsFASTBOOT(): Receive READY succeed!` 和 `reboot to fastboot mode success!`；
6. 设备实际进入 Fastboot，随后执行 `fastboot flashing unlock`。

教程还记录了两名参与者在 4.2.0 时期设备上的成功反馈。因此本文接受以下现场结论：

> 在教程对应的设备与软件组合上，只回写旧 LK、保留设备原有 Preloader，再配合 AUP，可以恢复 LK Fastboot 并完成解锁。

原始 Word 教程未随本仓库发布。本文只转述与复现有关的技术流程和证据边界，不包含作者身份、设备唯一信息、截图或原始附件。

### 2.2 成功事实与复现元数据要分开

教程没有保留以下信息：

- 所用旧 LK 的文件名、版本、字节数和 SHA-256；
- 测试机的活动槽；
- `lk_a`、`lk_b`、`pl_a`、`pl_b` 的刷前与刷后哈希；
- `fastboot devices`、`fastboot getvar` 和解锁命令的完整原始输出；
- AUP 前是否执行过会持久化 boot mode 的重启命令；
- 完整的 VCOM/USB trace。

这些缺口只影响我们精确识别教程当时的 LK、Preloader 和内部模式切换路径，不影响成功事实成立。当前工作是在版本、哈希和槽位都明确的 V260629 样机上复现同一方法，而不是重新判断教程是否成功。

## 3. 方法为什么有效

### 3.1 启动链分工

```text
BootROM
  │ 验证并运行 Preloader；根信任来自 SoC/eFuse 策略
  ▼
Preloader
  │ 选择 lk_a / lk_b，验证 LK 的证书链和镜像认证信息
  │ 处理主机早期 READY/FASTBOOT 类模式切换请求
  ▼
LK
  │ 初始化显示、USB 和 Fastboot
  │ 注册 getvar/download/flash/erase 等命令
  ▼
Android boot / recovery / fastbootd
```

因此，“恢复 Fastboot”实际包含两个问题：

1. Preloader 如何选择进入 LK Fastboot；
2. LK 启动后是否向主机注册完整的 Fastboot 命令。

降级 LK 直接解决第 2 个问题。社区实测教程则证明，在其测试组合中，AUP 成功解决了第 1 个问题。

### 3.2 三种容易混淆的 Fastboot

- **Preloader 早期请求**：主机在 VCOM 阶段要求设备下一步进入 LK Fastboot；
- **LK Fastboot**：提供 `fastboot devices`、`getvar`、`flash`、`erase` 等协议；
- **fastbootd**：Android recovery/userspace 中的 Fastboot，不等于 LK Fastboot。

`adb reboot bootloader` 的目标通常是 LK Fastboot；`adb reboot fastboot` 可能进入 fastbootd，二者不能混写。

### 3.3 驱动与 AUP 分别负责什么

教程所称的“新版 mtkclient 驱动”，实际是 MediaTek CDC ACM/VCOM 驱动。驱动只把 Windows 串口读写转换为 USB Bulk 传输，不识别 `READY`、`FASTBOOT`，也不实现 `CMD_BootAsFASTBOOT`。

真正的模式切换逻辑位于 AUP/Android Utility 用户态程序中，由它通过 Windows `ReadFile`、`WriteFile` 与 Preloader 交换命令。驱动决定链路能否通信，AUP 决定发送什么协议内容，设备端 Preloader 决定如何处理。

AUP 打印 `reboot to fastboot mode success!` 只说明串口交换走完，单独看不能证明 Fastboot USB 已经枚举；最终应以 `fastboot devices` 和实际命令响应为准。社区实测教程不只记录了这行日志，还记录了实际进入 Fastboot 并执行解锁，因此不能把其成功案例归类为日志假阳性。

## 4. LS12 LK 的版本演变与镜像选择

### 4.1 五份样本的功能变化

| incremental | 版本身份 | LK SHA-256 | Preloader 早期入口 | LK `flash:` / `erase:` |
| --- | --- | --- | --- | --- |
| `1703659196` | V231227 | `a87979a827c005107c68395c88396ce14a418dff0a23f89d473797e1476b3296` | 保留 | 保留 |
| `1723478295` | V240813（推定） | `ad8f5ea2b16efd60eb72045b35263b8c290dc5b151d75045e78b2af9a83434bf` | 保留 | 保留 |
| `19` | V241216 | `c87d7cd3903ceccd82a2fb6f4ac127434091ba0e4691d331511e35bb44654419` | 保留 | 保留 |
| `239` | V260523 | `6ebc4667ef9c0a6a888bda6d020cd744967e966c63b4d0ee6a07e5a21bce3b6a` | 保留 | 保留 |
| `260` | V260629 | `4b5f932dee1d3d6f42a23a4f25c058fae7c7c14488b44d5df0959c6c7252f80e` | 存在静态拒绝分支；AUP 真机路径待核 | **移除标准入口** |

V260629 LK 不是完全没有 Fastboot。它仍注册 `getvar:`、`download:`、`boot`、`continue`、重启和切槽命令，也保留多套底层存储写擦函数；被裁掉的是向 Fastboot 主机注册标准 `flash:`、`erase:` 的入口。

`V240813（推定）` 表示 incremental `1723478295` 和 2024-08-13 构建日期已经确认，但尚未取得 A 槽 `ro.genie.gota.version=V240813` 的直接证据。

V260523 与 V260629 的确认窗口只有 37 天。准确说法是：

> V260523 / incremental `239` 是当前最后一份已确认保留完整 Fastboot 入口的 LS12 样本；V260629 / incremental `260` 已确认收紧。缺少的中间构建不能仅凭日期推定功能状态。

### 4.2 为什么优先选择 V260523 / 239

V260523 / incremental `239` 是当前最合适的 LK-only 研究对象：

- 与 V260629 时间最接近，版本跨度最小；
- LK 与 V241216 使用相同源码修订标识 `dfde152c`；
- 已确认保留标准 `flash:`、`erase:`；
- OTA payload、设备实读镜像和发布的 8 MiB 分区镜像可相互校验；
- 五份 LS12 LK 的 `cert1`、被授权公钥和主 DTB 保持连续，没有观察到信任根轮换。

发布信息：

- Release：<https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/ls12-lk-v260523-r1>
- 文件：`lk_a-v260523.img`
- 字节数：`8,388,608`
- SHA-256：`6ebc4667ef9c0a6a888bda6d020cd744967e966c63b4d0ee6a07e5a21bce3b6a`

文件名中的 `lk_a` 表示样本来源槽位，不表示它只能写入 A 槽。该镜像也来自 OTA 中的通用 `lk.img`，补零至 8 MiB 后与设备 A 槽实读一致；这支持镜像未经人为修改，但跨槽使用仍应通过写后读回和真机启动验证。

教程没有留下旧 LK 哈希，因此不能断言其当时使用的就是 `239`。V231227 的有效旧镜像是 `lk_a.img`，哈希为 `a87979a8…`；同批备份中的 `lk_b.img` 是 8 MiB 全零文件，哈希 `2daeb1f3…`，**绝对不能刷入**。

## 5. 当前 V260629 样机的实际状态

### 5.1 混合 A/B 启动链

2026-07-19 对一台已授权 root 的 V260629 样机做只读核对，得到：

| 项目         | A 槽                      | B 槽（活动槽）                |
| ------------ | ------------------------- | ----------------------------- |
| Preloader    | V231227，哈希 `ee05973a…` | V260629，哈希 `76e76d56…`     |
| LK           | V231227，哈希 `a87979a8…` | V260629，哈希 `4b5f932d…`     |
| Android 属性 | —                         | `V260629` / incremental `260` |

另一台已连接设备同样报告活动槽 `_b`、V260629 / incremental `260`，但没有 root，未读取分区哈希。

这说明 OTA 后可以形成“旧 A + 新 B”的混合状态，也说明系统 UI 显示 V260629 并不能证明两个槽位的 Preloader/LK 都是 V260629。

A 槽保留旧启动链也不等于它是可靠救援槽。当前机器的 BROM 不支持 Preloader 降级，切换到旧 A 槽仍可能在 Preloader 执行前被拒绝；Preloader 认证失败后是否自动回退另一槽也没有充分动态证据。

### 5.2 本次 LK-only 会改变什么

当前刷写前状态为：

```text
活动槽：_b
系统：V260629 / incremental 260

A 槽：V231227 Preloader → V231227 LK
B 槽：V260629 Preloader → V260629 LK → V260629 Android

verifiedbootstate=green
flash_locked=1
vbmeta_state=locked
sys.oem_unlock_allowed=0
```

将 V260523/239 LK 写入活动 B 槽后，组合变为：

```text
A 槽：V231227 Preloader → V231227 LK
B 槽：V260629 Preloader → V260523/239 LK → V260629 Android
                         └─ 只替换这一层
```

写入时不会立即影响当前 Android，因为本轮启动已经越过 LK。重启后的三个主要观察点是：

| 后续动作 | 预期控制流 | 当前判断 |
| --- | --- | --- |
| 正常重启 | V260629 Preloader 验证并运行 239 LK，再由 239 LK 启动 V260629 Android | 较可能正常，但当前精确组合尚未真机验证 |
| `adb reboot bootloader` | Android 保存 bootloader reboot reason，Preloader 加载 239 LK，239 LK 启动完整 Fastboot | 最适合区分 Preloader 入口与 LK 命令面的诊断路径 |
| 完全关机后使用 AUP | AUP 与 V260629 Preloader 交换模式切换命令，再由 Preloader 加载 239 LK | 社区教程已有成功先例；当前精确组合待直连复现 |

239 是未经修改的原厂签名 LK，现有样本的证书链、被授权公钥和主 DTB 保持连续，239 与 260 之间也没有观察到分区布局变化。这些证据支持兼容性，但不等于已经排除防回滚或新旧 Android 组件之间的动态差异。

### 5.3 怎样理解 V260629 Preloader 的静态拒绝分支

V260629 Preloader 仍识别早期 ASCII `FASTBOOT`，但静态代码中存在 user build 拒绝分支，不再按旧路径回送 ACK、设置 Fastboot boot mode 99 并切换到 LK Fastboot。AUP v152 又会发送相同的 ASCII `FASTBOOT`，所以该分支值得在当前机器上继续核实。

现有静态分析没有证明 AUP 的完整帧序列在真机上必然落入该分支，也不能排除附加二进制帧、已有 boot mode 或其他状态触发另一条有效路径。正确关系是：

1. 社区实测教程确认“旧 LK + AUP”在实际设备上成功过；
2. 静态分析提示 V260629 的内部模式切换路径仍需动态确认；
3. 当前样机负责验证 V260629 Preloader + V260523/239 LK 是否原样复现。

因此不能写成“V260629 Preloader 已动态确认拒绝 AUP”，也不能依据这一静态分支预设当前复现会失败。

## 6. LK-only 受控操作流程

下面是针对“活动槽为 B、使用 V260523/239 镜像”的研究流程。社区实测教程已经证明方法可行；这里的命令进一步补充了当前设备的真实分区名、镜像哈希和写后校验。

### 6.1 停止条件

满足任意一项就不要继续：

- 设备不是 `ls12_mt8797_wifi_64` / TALIH-PD2；
- 没有可靠 root；
- 没有人工确认 `ro.boot.slot_suffix`；
- 没有把 `lk_a`、`lk_b` 和当前 Preloader 备份到电脑并记录哈希；
- 镜像大小不是精确的 8 MiB，或 SHA-256 不匹配；
- 没有直连 Windows USB、已验证驱动和可执行的恢复计划；
- 设备是唯一可用样机，且不能接受无法启动或清空 userdata。

### 6.2 确认设备身份和活动槽

多台 ADB 设备并存时必须显式指定序列号：

```sh
export XPAD_SERIAL='替换为目标设备序列号'

adb -s "$XPAD_SERIAL" shell getprop ro.product.device
adb -s "$XPAD_SERIAL" shell getprop ro.boot.slot_suffix
adb -s "$XPAD_SERIAL" shell getprop ro.genie.gota.version
adb -s "$XPAD_SERIAL" shell getprop ro.build.version.incremental
adb -s "$XPAD_SERIAL" shell 'ls -l /dev/block/by-name/lk_a /dev/block/by-name/lk_b'
```

当前 V260629 B 槽样机的预期基线是：

```text
ro.product.device=ls12_mt8797_wifi_64
ro.boot.slot_suffix=_b
ro.genie.gota.version=V260629
ro.build.version.incremental=260
```

### 6.3 使用真实的 LK 分区路径

教程中的路径：

```text
/dev/block/by-name/lk
```

在当前连接的两台 LS12 V260629 设备上都不存在。真实路径为：

```text
/dev/block/by-name/lk_a -> /dev/block/sdc38
/dev/block/by-name/lk_b -> /dev/block/sdc55
```

两台设备的分区位置一致：

| 槽位 | by-name 路径 | 当前实读块设备 | 起始扇区 | 扇区数 | 字节数 |
| --- | --- | --- | --: | --: | --: |
| A | `/dev/block/by-name/lk_a` | `/dev/block/sdc38` | 1,345,536 | 16,384 | 8,388,608 |
| B | `/dev/block/by-name/lk_b` | `/dev/block/sdc55` | 1,873,920 | 16,384 | 8,388,608 |

活动槽为 `_b` 时，本次目标是 `/dev/block/by-name/lk_b`。应优先使用带槽位语义的 by-name 路径；`sdc55` 只作为映射核对证据，不能在其他机器上盲目硬编码。

### 6.4 备份两槽 LK 和当前 Preloader

先确认 root，再只读备份。示例中的 `.before.img` 不能覆盖已有恢复文件：

```sh
adb -s "$XPAD_SERIAL" shell 'su -c "id"'

adb -s "$XPAD_SERIAL" shell \
  'su -c "dd if=/dev/block/by-name/lk_a of=/sdcard/lk_a.before.img bs=1048576 && sync"'
adb -s "$XPAD_SERIAL" shell \
  'su -c "dd if=/dev/block/by-name/lk_b of=/sdcard/lk_b.before.img bs=1048576 && sync"'
adb -s "$XPAD_SERIAL" shell \
  'su -c "dd if=/dev/block/mapper/pl_a of=/sdcard/preloader_a.before.img bs=1048576 && sync"'
adb -s "$XPAD_SERIAL" shell \
  'su -c "dd if=/dev/block/mapper/pl_b of=/sdcard/preloader_b.before.img bs=1048576 && sync"'

mkdir ./xpad2-before-new
adb -s "$XPAD_SERIAL" pull /sdcard/lk_a.before.img ./xpad2-before-new/
adb -s "$XPAD_SERIAL" pull /sdcard/lk_b.before.img ./xpad2-before-new/
adb -s "$XPAD_SERIAL" pull /sdcard/preloader_a.before.img ./xpad2-before-new/
adb -s "$XPAD_SERIAL" pull /sdcard/preloader_b.before.img ./xpad2-before-new/
shasum -a 256 ./xpad2-before-new/*.img
```

备份必须复制到电脑并记录哈希。只留在设备 userdata 中不算恢复备份，因为解锁通常会清空 userdata。

### 6.5 校验 V260523/239 LK

在电脑上检查：

```sh
wc -c lk_a-v260523.img
shasum -a 256 lk_a-v260523.img
```

结果必须精确为：

```text
8388608
6ebc4667ef9c0a6a888bda6d020cd744967e966c63b4d0ee6a07e5a21bce3b6a
```

然后推送到设备并再次校验：

```sh
adb -s "$XPAD_SERIAL" push lk_a-v260523.img /data/local/tmp/lk-v260523-239.img
adb -s "$XPAD_SERIAL" shell \
  'su -c "sha256sum /data/local/tmp/lk-v260523-239.img"'
adb -s "$XPAD_SERIAL" shell \
  'su -c "blockdev --getsize64 /dev/block/by-name/lk_b"'
```

设备端镜像哈希必须一致，目标 `lk_b` 大小必须为 `8388608`。

### 6.6 写入 B 槽并立即读回

仅当活动槽已经人工确认为 `_b`，且目标映射再次核对无误，才执行：

```sh
adb -s "$XPAD_SERIAL" shell \
  'su -c "dd if=/data/local/tmp/lk-v260523-239.img of=/dev/block/by-name/lk_b bs=1048576 && sync"'

adb -s "$XPAD_SERIAL" shell \
  'su -c "sha256sum /dev/block/by-name/lk_b"'
```

读回哈希必须仍为：

```text
6ebc4667ef9c0a6a888bda6d020cd744967e966c63b4d0ee6a07e5a21bce3b6a
```

哈希不一致时不要重启。应在 Android 仍运行时查明原因，或恢复原始 `lk_b.before.img`。

### 6.7 验证进入 LK Fastboot

可以验证两条入口。先用 `adb reboot bootloader` 有利于单独确认 LK 命令面，不代表社区教程中的 AUP 路径优先级更低。

路径 A：

```sh
adb -s "$XPAD_SERIAL" reboot bootloader
```

路径 B（社区教程已验证的方法）：

1. 安装 MediaTek PreLoader USB VCOM 2023 驱动；
2. 设备完全关机；
3. 使用直连 Windows USB，不经 Tailscale/USB-over-IP；
4. 在 AUP 中执行 `Reboot Fastboot mode`；
5. 立即用 Fastboot 客户端确认实际枚举。

无论使用哪条入口，先做只读检查：

```sh
fastboot devices
fastboot getvar product
fastboot getvar current-slot
fastboot getvar unlocked
```

屏幕停留在充电图但 `fastboot devices` 有响应时，以协议响应为准；屏幕发生变化但主机没有 Fastboot 设备时，不能认定进入成功。

## 7. 进入 Fastboot 后如何处理解锁

恢复完整 LK Fastboot 命令面，不等于设备已经解锁，也不等于 locked 状态下允许任意分区写入。

### 7.1 标准 Fastboot 解锁

只有 Fastboot 稳定枚举、只读查询正常、备份已经离机后，才考虑：

```sh
fastboot flashing unlock
```

这通常会清空 userdata 并改变 AVB 状态。当前样机报告：

```text
flash_locked=1
vbmeta_state=locked
sys.oem_unlock_allowed=0
```

因此标准 Fastboot 解锁可能被 OEM 策略拒绝。社区成功案例中的设备已开启 OEM 解锁开关；当前样机是否具备相同许可，需要单独判断。

### 7.2 BROM/DA 软件解锁是另一条路线

`sys.oem_unlock_allowed=0` 不能外推为所有软件解锁都不可能。mtkclient 上游另有：

```sh
python mtk.py da seccfg unlock
```

该命令通过可用的 Download Agent 修改 `seccfg` 锁状态，不依赖 LK 对 `fastboot flashing unlock` 的标准许可。Kamakiri、Kamakiri2、MTK-bypass 解决的是 BROM/DA 访问以及 DAA/SLA/SBC 这一层；它们本身不等于已经解锁，后续仍需要可用 DA 和适配当前设备的 `seccfg` 格式。

两条路线应分开记录：

| 路线 | 当前状态 |
| --- | --- |
| 239 LK → `fastboot flashing unlock` | 可恢复命令面；当前 OEM 许可为 0，标准解锁可能被拒绝 |
| BROM/DA → `mtk.py da seccfg unlock` | 上游命令和原理存在；XPad2/MT8797 的 Kamakiri/DAA/SLA 兼容性尚未实测 |

上游用法见 [Unlock flow for stock MTK](https://github.com/bkerler/mtkclient/blob/main/README-USAGE.md#unlock-flow-for-stock-mtk-with-android-9) 和 [BROM exploit / DA usage](https://github.com/bkerler/mtkclient/blob/main/README-USAGE.md#bypass-sla-daa-and-sbc-using-generic_patcher_payload)。

## 8. 为什么不能同时降级 Preloader

### 8.1 功能配对与 BROM 许可是两回事

V260523 Preloader 和 V260523/239 LK 在功能上最完整：

- Preloader 保留早期主机 Fastboot 入口；
- LK 注册标准 `flash:`、`erase:`。

但当前机器已经确认 **BROM 不支持 Preloader 降级**。所以“旧 Preloader + 旧 LK”只能作为静态功能对照，不能转化为当前机器的刷写方案。

### 8.2 Linux 可写不代表下次能启动

当前 root 样机只读复核得到：

```text
/dev/block/mapper/pl_a -> /dev/block/dm-10 -> /dev/block/sda
/dev/block/mapper/pl_b -> /dev/block/dm-11 -> /dev/block/sdb

pl_b mapper：4,190,208 bytes，blockdev --getro = 0
sdb Boot LUN：4,194,304 bytes
```

对 `/dev/block/sdb` 跳过前 4,096 字节后计算的 SHA-256，与 `/dev/block/mapper/pl_b` 完全一致。这证明 Linux 可以访问 mapper raw，也说明完整 UFS Boot LUN 比 raw Preloader 多一层 4 KiB 包装。

它不证明 BROM 会接受写入的旧 Preloader。BROM 验证发生在 Android、mapper 和 Preloader 自身运行之前；`dd` 成功无法绕过启动时的版本或认证限制。

如果把旧 Preloader 写入活动 B 槽，下次启动可能在最早阶段停止：

```text
BootROM
  → 检查活动 B 槽的旧 Preloader
  → 因 Preloader 降级限制拒绝
  ✕ 不会进入旧 Preloader
  ✕ 不会加载 239 LK
  ✕ AUP 的 Preloader VCOM/Fastboot 请求链也无法成立
```

因此：

> 不要向当前机器的 `/dev/block/mapper/pl_b` 写入 V260523 或 V231227 Preloader，也不要把 mapper raw 镜像直接写入 `/dev/block/sdb`。

直接写 `/dev/block/sdb` 还会覆盖 4 KiB UFS 包装头，并把 raw Preloader 放在错误偏移。

当前研究边界是：

```text
允许研究：V260629 Preloader → V260523/239 LK
禁止降级：V260523/239 Preloader → V260523/239 LK
```

文档保留旧 Preloader 镜像、哈希和 mapper 格式关系用于研究与恢复识别，但不提供当前机器的 Preloader 写入命令。

## 9. 风险与回滚

### 9.1 主要风险

| 风险 | 可能表现 | 处理原则 |
| --- | --- | --- |
| 把 `lk` 当成真实分区 | 命令失败或写错目标 | 读取活动槽，明确使用 `lk_a` 或 `lk_b` |
| 根据镜像文件名选择目标槽 | 将来源槽误当目标槽 | 文件名只记录来源；目标由活动槽和实验设计决定 |
| 239 LK 与新 Android 存在动态差异 | Fastboot 可用但 Android 启动异常 | 把“进入 Fastboot”和“长期混用启动链”分开验证 |
| 签名连续但存在防回滚 | Preloader 拒绝旧 LK | 同根密钥不等于没有版本策略 |
| 把旧 A 槽当成确定救援槽 | 切槽后仍无法启动 | BROM 不支持旧 Preloader，自动回退也未证实 |
| AUP 打印 success 但无 Fastboot 枚举 | 工具显示成功，电脑无设备 | 以 `fastboot devices/getvar` 为准 |
| 把 VCOM 驱动当作模式命令实现 | 更换驱动后仍无法进入 | 驱动负责传输，AUP 负责命令 |
| 把 Fastboot 解锁等同于关闭启动链验签 | patch LK 仍被拒绝 | AVB 锁状态通常不会关闭 Preloader 对 LK 的认证 |
| OTA 覆盖已降级 LK | Fastboot 功能再次消失 | 实验期禁用自动 OTA，更新前恢复一致状态 |
| 混入 LS14/build 262 镜像 | 镜像不兼容或无法启动 | 不跨产品线使用 `779cd911…` 等 LS14 样本 |

最坏情况下，V260629 Preloader 可能拒绝 239 LK，或 239 LK 无法继续启动 V260629 Android，设备可能黑屏、停在充电界面、循环重启或只剩 VCOM。在开始前没有可靠恢复通道时，不应覆盖唯一可启动槽。

### 9.2 Android 仍可启动

把电脑中的原始 B 槽备份推回设备，先校验，再恢复：

```sh
adb -s "$XPAD_SERIAL" push ./xpad2-before-new/lk_b.before.img /data/local/tmp/lk_b.restore.img
adb -s "$XPAD_SERIAL" shell \
  'su -c "sha256sum /data/local/tmp/lk_b.restore.img"'
adb -s "$XPAD_SERIAL" shell \
  'su -c "dd if=/data/local/tmp/lk_b.restore.img of=/dev/block/by-name/lk_b bs=1048576 && sync"'
adb -s "$XPAD_SERIAL" shell \
  'su -c "sha256sum /dev/block/by-name/lk_b"'
```

最后的读回哈希必须与刷前记录一致。

### 9.3 Android 不启动，但 Fastboot 可用

优先恢复原始 `lk_b`，或切回已经确认能启动的槽。Fastboot 是否允许写 `lk_b` 取决于设备锁状态、命令白名单和分区策略，不能预设一定可写。

### 9.4 Android 和 Fastboot 都不可用

此时只能依赖已经验证的 BootROM/Preloader/DA 恢复通道或硬件级方案。当前机器不支持 Preloader 降级，而 DAA/SLA、DA 恢复和旧槽自动回退都尚未构成确定保证。

## 10. 当前复现实验应记录什么

同一台设备、同一条直连 USB 线和同一 AUP 下，最有价值的对照是：

```text
V260629 Preloader + V260629 LK  → 基线
V260629 Preloader + V260523 LK  → 检验 LK-only
```

`V260523 Preloader + V260523 LK` 只作为静态功能对照，不能列入当前机器的真机刷写实验。

每次成功或失败都应保存：

1. `ro.product.device`、系统版本、incremental 和活动槽；
2. 刷写前 `pl_a`、`pl_b`、`lk_a`、`lk_b` 的字节数与 SHA-256；
3. 所刷 LK 的文件名、来源、字节数和 SHA-256；
4. 写入目标的完整块设备路径；
5. 写入后的分区读回 SHA-256；
6. 进入方式：`adb reboot bootloader`、冷机 AUP、按键或其他；
7. Windows 驱动版本、AUP 版本和 USB VID/PID 变化；
8. VCOM 原始收发字节或 USB trace；
9. `fastboot devices`、`getvar product/current-slot/unlocked` 的原始输出；
10. 解锁返回值、是否清空 userdata、重启后 Android 是否正常；
11. 失败后的恢复路径是否真实执行成功。

## 附录 A：AUP `CMD_BootAsFASTBOOT` 静态分析

已分析环境：

- MediaTek CDC ACM/VCOM 驱动：`DriverVer 01/04/2023, 3.0.1512.0`；
- Android Utility/AUP v152 原生 x86 程序；
- `AndroidUtility.exe` SHA-256：`23b7b3ce1f3b7048be88272cf64456573cce774d94e1a85884941d8e427cfeaf`。

AUP v152 中恢复出的发送顺序为：

```text
read  "READY" × 4
write "FASTBOOT"
write 040000000100000001000000
write 0400000001000000010000C0
write 0600000001000000010000C000800000
read  13 bytes
write 040000000100000001000000
read  13 bytes
write "DISCONNECT"
print success
```

AUP 严格检查前四次 `READY`，但后续两次 13 字节读取只检查 I/O 是否完成，未比较返回内容，也没有等待 Windows 出现 Fastboot USB 设备。这解释了为什么 success 文本本身不是 Fastboot 已枚举的充分证据。

## 附录 B：USB-over-IP 实测记录

一次经 Tailscale + VirtualHere 的物理 USB 代理测试已经做到：

- Windows 枚举 Android `VID_0E8D&PID_201C`；
- 重启后捕获 Preloader `VID_0E8D&PID_2000` 和 VCOM `COM3`；
- 从真机读到四次 `READY`；
- 成功写出 ASCII `FASTBOOT`。

在随后的二进制帧阶段，约 20 ms 往返延迟的代理链路出现 Win32 error 31，设备返回 Android。分开发送和合并发送都没有完成整段协议。

这次测试证明 USB 代理、VCOM 枚举和 Preloader `READY` 均为真实链路，但没有证明或否定 239 LK 能否进入 Fastboot。最终动态结论应由直连 Windows 测试得出。

## 附录 C：参考资料

- [XPad2 启动链参考仓库](https://github.com/yoyicue/xpad2-v231227-bootchain-reference)
- [五版本 Preloader/LK 演变报告](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/blob/main/reports/bootchain-evolution-1703659196-to-260.md)
- [BootROM / Preloader 验证逻辑](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/blob/main/reports/bootrom-preloader-verification.md)
- [五份 LK 静态差异报告](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/blob/main/reports/lk-v231227-vs-v260.md)
- [V260523 / incremental 239 Release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/ls12-lk-v260523-r1)
- [V260629 受限 Fastboot Release](https://github.com/yoyicue/xpad2-v231227-bootchain-reference/releases/tag/ls12-v260629-restricted-fastboot-r1)
- [mtkclient 官方使用说明](https://github.com/bkerler/mtkclient/blob/main/README-USAGE.md)

本文将社区实测教程作为成功案例证据，将镜像版本、命令能力、哈希和当前设备槽位状态分别交由公开样本、静态分析和只读实测支持。缺失的原始元数据用于界定精确复现范围，不用于否定已经发生的成功结果。
