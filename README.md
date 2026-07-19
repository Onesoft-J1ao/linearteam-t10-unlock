# linearteam-t10-unlock

iFLYTEK T10 (CB-CTG2.0) 学习机全解锁 Magisk 模块 — 欺骗云端，本地自由

## 设备信息

| 项目 | 值 |
|------|-----|
| 型号 | CB-CTG2.0 / T10 |
| 品牌 | iFLYTEK (科大讯飞) |
| SoC | UNISOC ud710_2h10 (紫光展锐) |
| Android | 9 (PPR1.180610.011, SDK 28) |
| 系统版本 | iFLY_V2.08.3 |
| 架构 | ARM64-v8a, cortex-a55 |
| Magisk | 30.7 |

## 封控链路完整分析

通过反编译 4 个核心 APK (IflytekServer, HwcService, IFlyMdm, TyeLauncher) 和系统框架，还原了讯飞学习机的完整管控体系：

### 架构总览

```
┌─────────────────────────────────────────────────────────────────┐
│                       云端服务器                                  │
│  api.xunfeixxj.com / k12-api.openspeech.cn / k12-swift...     │
└──────────┬────────────────────────────┬─────────────────────────┘
           │ HTTP REST + Push SDK       │ gRPC/WebSocket
           ▼                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  IFlyMdm (com.iflytek.ebg.aistudy.mdm)                         │
│  - 下载管控策略 (AppControlConfig, XXJForbidAPI)                 │
│  - 上报使用数据 (AppUseRecord, UploadLocalApps)                  │
│  - 心跳保活 (HeartbeatCheckNetworkUtil)                          │
│  - Content Provider 数据共享                                      │
│  - Device Admin 锁屏权限                                          │
│                                                                   │
│  关键: AppControlManager.setForbiddenPackage() 是空壳SDK          │
│  真正的封锁通过 AIDL → TyeLauncher 执行                           │
└──────┬───────────────┬──────────────────┬───────────────────────┘
       │ AIDL          │ AIDL             │ Broadcast
       ▼               ▼                  ▼
┌──────────────┐ ┌────────────────┐ ┌────────────────────────────┐
│ HwcService   │ │ IflytekServer  │ │ IFlytekService             │
│ (HW控制)     │ │ (安全服务)      │ │ (进程看门狗)                │
│              │ │                │ │                              │
│ 禅模式锁屏    │ │ IZenMode       │ │ forceStopPackage()          │
│ 亮度/色温     │ │ IAppSecurity   │ │ 前台App监控                  │
│ USB封锁      │ │ IHardwareSec   │ │ 摄像头电机封锁               │
│ 自习模式      │ │ INetworkSec    │ │ Home/Recent键拦截            │
│ 手势控制      │ │ IPermissionSec │ │ 弹窗拦截                    │
└──────────────┘ └────────────────┘ └────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────┐
│  TyeLauncher (com.toycloud.launcher)                              │
│                                                                    │
│  ControlAppService (AIDL服务)                                      │
│    接口: IControlApp.onControl(List<String> lockedApps)            │
│    Transaction: 1, Descriptor: "com.iflytek.ebg.aistudy...        │
│                  ...mdm_sdk.apps.IControlApp"                       │
│                                                                    │
│  → RemoteController.refreshIcons(Set)                              │
│    → mControlApps 存储被锁App包名                                   │
│    → 桌面在App图标上画 X 遮罩                                       │
│    → 点击被锁App时弹出"应用已被禁用"                                  │
│                                                                    │
│  ⚠️ App在PackageManager中并未被disable!                            │
│     只是桌面UI层屏蔽了图标和启动                                      │
└──────────────────────────────────────────────────────────────────┘
```

### App封锁的具体流程

1. 云端下发 `AppControlConfig` → IFlyMdm 存储
2. IFlyMdm 通过 `LauncherClient` AIDL 绑定到 TyeLauncher 的 `ControlAppService`
3. 调用 `IControlApp.onControl(List<String> lockedApps)` 传递被锁App包名列表
4. TyeLauncher 的 `RemoteController.refreshIcons()` 更新 `mControlApps` 集合
5. 桌面在 `lockedApps` 中的App图标上画 **X 遮罩**
6. 用户点击被锁App → 桌面拦截启动，弹出禁用提示

**关键发现**: `pm enable` 完全无效，因为App在PackageManager中根本没有被disable，封锁是TyeLauncher在UI层实现的。

### 禅模式锁屏流程

1. IflytekServer 的 `ZenModeService` 调用 `NotificationManager.setZenMode()`
2. HwcService 的 `SelfStudyModeService` 控制自习模式
3. `blank_screen` 二进制执行黑屏
4. `persist.hwc.zenmode.intercepted` 属性控制拦截开关

### DNS防火墙

`tiny_firewall.sh` 用 iptables 在 FORWARD/INPUT/OUTPUT 链上 DROP:
- UDP dport 53 (DNS)
- TCP dport 853 (DNS over TLS)
- ICMPv6 type 143 (MLD)

### 安装白名单

- `persist.vendor.iflytek.install_whitelist_enable=true` (build.prop)
- PackageInstaller 被注入 `IflyFilterInvisiblePkg`, `WhiteList` 等类
- 只有白名单内App可安装

### 后台监控/隐私收集

| 服务 | 功能 |
|------|------|
| ylog | 内核/modem日志收集 |
| log_service | 系统日志 |
| collect_apr | ANR/崩溃报告 |
| phonedump.conf | 联系人/WiFi密码/GPS/蓝牙抓包 |
| dataLogDaemon | 数据日志 |
| cmd_services | 远程命令执行 |
| IFlytekService | 前台App监控+强制杀进程 |

### 框架层注入

5个 iflytek jar 在 Zygote 预加载阶段注入 system_server:
- `iflytek-frameworks-service.jar`
- `iflytek-monitor-lib.jar`
- `iflytek-prediction.jar`
- `iflytek-server-lib.jar`
- `iflytek-security-lib.jar`
- `hwc-framework-service.jar`

## 模块策略：欺骗云端

**核心原则**: 不禁用任何 iflytek App，让它们正常运行、正常心跳、正常上报。只对抗它们的执行结果。

| 对抗项 | 机制 | 说明 |
|--------|------|------|
| App封锁(X遮罩) | `service call` AIDL调空列表 + 广播 | 清空TyeLauncher的mControlApps |
| App禁用 | `pm enable` 兜底 | 以防MDM也用pm disable |
| 禅模式锁屏 | `settings put global zen_mode 0` + keyguard解锁 | 对抗ZenModeService |
| blank_screen | `stop blank_screen` | 杀黑屏二进制 |
| DNS防火墙 | 清除 iptables 53/853 DROP规则 | 恢复自定义DNS |
| 安装白名单 | `resetprop install_whitelist_enable false` | 允许安装任意App |
| 进程看门狗 | `pm disable com.android.iflytek` | 禁用IFlytekService |
| Device Admin | `dpm remove-active` | 移除MDM锁屏权限 |
| MDM控制数据 | `content delete` 清空provider | 清空管控策略缓存 |
| ADB认证 | `stop adbd; start adbd` + `ro.adb.secure=0` | 开启无认证ADB |
| 日志收集 | 停7个日志服务 + 定期清目录 | 阻止隐私上传 |
| 配置文件 | bind mount空配置覆盖 | 清空黑名单/杀后台配置 |

## 文件结构

```
t10_unlock_v3/
├── META-INF/com/google/android/
│   ├── update-binary
│   └── updater-script
├── module.prop
├── post-fs-data.sh      # system_server启动前执行：删iflytek框架jar
├── service.sh            # 开机后执行：初始化+启动daemon
├── daemon.sh             # 常驻守护：3秒轮询对抗所有管控
├── customize.sh          # 首次安装：禁用看门狗+清MDM数据
└── system/etc/           # bind mount覆盖的空配置文件
    ├── blackAppList.xml
    ├── appPowerSaveConfig.xml
    ├── ifly_bg_clean_conf.xml
    ├── ifly_syscomponent_package_list.xml
    └── phonedump.conf
```

## 安装

1. 确保已解锁 Bootloader 并安装 Magisk 30.7+
2. 在 Magisk 中卸载旧版解锁模块
3. 安装 `t10_unlock_v3.zip`
4. 重启

## 反编译发现的关键AIDL接口

### TyeLauncher ControlAppService

```
AIDL接口:    com.iflytek.ebg.aistudy.mdm_sdk.apps.IControlApp
方法:        onControl(List<String> lockedApps)
Transaction: 1
Descriptor: "com.iflytek.ebg.aistudy.mdm_sdk.apps.IControlApp"
Service:    com.toycloud.launcher/.model.launcher.appcontrol.ControlAppService
```

调用空列表清空锁定:
```bash
service call com.toycloud.launcher.model.launcher.appcontrol.ControlAppService 1 \
  s16 "com.iflytek.ebg.aistudy.mdm_sdk.apps.IControlApp" i32 0
```

### IflytekServer 服务接口

| 接口 | 实现类 | 功能 |
|------|--------|------|
| IIflytekService | IflytekServiceImpl | 总调度 |
| IZenMode | ZenModeService | 禅模式控制 |
| IAppSecurity | AppSecurityService | App安全(空壳) |
| IHardwareSecurity | HardwareSecurityService | 硬件监控 |
| IInformationSecurity | InformationSecurityService | 信息安全 |
| INetworkSecurity | NetworkSecurityService | 网络安全/URL过滤 |
| IPermissionSecurity | PermissionSecurityService | 权限管理 |
| ISystemSecurity | SystemSecurityService | 系统安全 |

### HwcService 服务接口

| 接口 | 实现类 | 功能 |
|------|--------|------|
| IHwcService | HwcServiceImpl | 总调度 |
| IDisplayService | DisplayService | 亮度/色温 |
| IAudioControlService | AudioControlService | 音频控制 |
| IUsbForbiddenService | UsbForbiddenService | USB封锁 |
| INetworkControlService | NetworkControlService | URL黑名单 |
| ISelfStudyModeService | SelfStudyModeService | 自习模式 |
| ILogService | LogService | 日志控制 |

### MDM云端API端点

| 端点 | 功能 |
|------|------|
| `/api/AppForbiddenApplyApi` | App禁用申请 |
| `/api/XXJForbidAPI` | 学习机禁用控制 |
| `/api/ScreenshotControlApi` | 截图控制 |
| `/api/UrlControlApi` | URL黑名单 |
| `/api/InternalSetting` | 内部设置 |

## 致谢

- linearteam
