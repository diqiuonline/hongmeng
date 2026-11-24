# 鸿蒙工作区开发与编译规则

## 1. HarmonyOS 项目默认使用低优先级限核编译

在本工作区（包括 `lkong-harmony`、`deepseek` 等所有 HarmonyOS 项目）中执行构建时，为避免 16 线程 CPU 被完全占满影响桌面与其他任务，**优先使用低优先级 + 4 核心限制编译**；除非用户明确要求全速构建，否则禁止直接运行 `devecocli build`（其内部会强制启用 `--parallel` 且默认不限核并拉起 Daemon）。

### 1.1 已配备 `scripts/build_low_cpu.py` 的项目（如 `lkong-harmony`）

在对应项目根目录执行：

- **Debug 构建**：
  ```powershell
  python scripts/build_low_cpu.py --mode debug --cores 4
  ```
- **Release 构建**：
  ```powershell
  python scripts/build_low_cpu.py --mode release --cores 4
  ```
- **Release 构建并发布签名**（仅 `lkong-harmony`）：
  ```powershell
  python scripts/rebuild_and_sign.py --cores 4
  ```
- 如先前曾启动过全速 Hvigor Daemon，可在命令后附加 `--stop-daemon` 清理旧守护进程。

### 1.2 尚未配备 `build_low_cpu.py` 的鸿蒙子项目（如 `deepseek`）

同样必须通过 Windows 低优先级（`IDLE_PRIORITY_CLASS`）+ 4 核亲和性掩码（`0x0F`）运行 `hvigorw.js`，并附加 `--no-parallel --no-daemon --incremental`（及 `DEVECO_SDK_HOME` 与 JBR `PATH` 环境变量），或先按同样方式补充 `scripts/build_low_cpu.py` 后再构建。
