OpenClaw Tunnel Pro 🚀

<p align="center">
<a href="#introduction-cn">中文说明</a> |
<a href="#introduction-en">English</a>
</p>

<h2 id="introduction-cn">🇨🇳 介绍 (Introduction)</h2>

最近开发的一个小工具：OpenClaw Tunnel Pro。

最初开发这个工具是为了解决自己在管理 OpenClaw 实例时，频繁切换 SSH 隧道和查看实时指标的痛点。我希望它既能提供原生应用的丝滑体验，又能保障服务器凭据的存储安全。现在项目已经迭代到了 v3.5.2 版本，各项功能已趋于稳定，因此分享出来给有同样需求的朋友使用。

🌟 核心功能

实时数据闭环：直接通过 SSH 通道轮询 CLI 指令，实时抓取并汇总 Token 消耗（支持 24 小时增量过滤）、活跃连接数和接口请求总量。

系统级安全存储：所有服务器地址、用户名及密码均通过 macOS 的 Keychain 或系统级加密接口进行存储，本地不保留任何明文配置文件。

自动化连接管理：支持多节点配置快速切换，并内置自动分配逻辑以避让本地端口冲突；集成毫秒级心跳监测，断线自动重连。

原生交互美学：macOS 版深度适配系统级物理动效，支持监控面板的阶梯式进场动画；Windows 版支持原生 Mica (云母) 半透明效果。

🛠️ 技术实现要点

数据传输纠错：在 macOS 端的 SSH 指令中引入 -T 参数以禁用远程伪终端（PTY）机制，彻底解决了长 JSON 数据流因 Linux 终端强制自动换行（\r\n）而导致解析失效的问题。

环境自适应：支持 OpenClaw CLI 的绝对路径调用（如 /root/.nvm/.../bin/openclaw），规避了非交互式 SSH 环境下环境变量丢失的顽疾。

高性能渲染：在 macOS 上采用原生 NSImageView 引擎加载 GIF 素材，绕过 WebKit 沙盒对本地文件访问的限制，并解决大尺寸素材溢出问题。

内存级隧道操作：Windows 版利用 Rust 的 ssh2 库在内存中直接建立隧道映射，显著降低了系统资源占用。

📜 进化史 (Changelog)

[v3.5.2]

引入 -T 参数禁用远程 PTY，修复超长数据截断问题；增加官方绝对路径支持；改用原生 NSImageView 渲染引擎。

[v3.5.1]

引入 Flexbox 约束修正 Windows 按钮对齐；启动时强制重置节点激活态，修复 UI 幽灵状态；物理级抹除 Windows 输入框白框。

[v3.5.0]

接入官方 CLI 统计，实现实时 Token、Links、Reqs 监测；新增作者信息模块与 GIF 动画支持；适配 macOS 26.0+ 高级动效。

[v3.0.0]

确立极客视觉规范；全面接入系统级 Keychain 安全存储架构。

[v2.0.0]

支持多服务器节点持久化与快速切换；增加自动避让逻辑支持隧道并发开启。

[v1.0.0]

完成基于 /usr/bin/expect 与 /usr/bin/ssh 的非交互式隧道建立核心逻辑。

<h2 id="introduction-en">🇺🇸 English Introduction</h2>

Hello! I’d like to share a small utility I’ve been working on: OpenClaw Tunnel Pro.

I originally developed this tool to scratch my own itch—specifically the friction of constantly switching SSH tunnels and manually checking metrics while managing OpenClaw instances. My goal was to build a solution that combines a fluid, native app experience with robust, system-level security for server credentials. Now that the project has reached v3.5.2 and the core features have matured, I’m opening it up for anyone who might find it helpful in their workflow.

🌟 Core Features

Real-time Observability: Polls CLI commands directly through established SSH tunnels to capture and aggregate Token consumption (with 24h incremental filtering), active session counts, and total request volume.

Cryptographically Secure: All server addresses, usernames, and passwords are managed via macOS Keychain or system-native encrypted stores. No sensitive data is ever stored in plaintext configuration files.

Intelligent Lifecycle Management: Effortlessly switch between multiple node profiles with built-in port-collision avoidance. Features millisecond-level heartbeat monitoring to ensure seamless automatic reconnection during network fluctuations.

Native Aesthetic Experience: Designed with a platform-first mindset. The macOS version utilizes system-native physical effects and staggered entrance animations, while the Windows version embraces the Mica translucent material design.

🛠️ Technical Highlights

Data Integrity via PTY Control: In the macOS client, I explicitly use the -T flag to disable remote PTY allocation. This prevents long JSON payloads from being truncated by the remote terminal's automatic line-wrapping (\r\n), ensuring 100% parsing accuracy.

Environment-Aware Execution: Implemented support for absolute CLI paths (e.g., /root/.nvm/.../bin/openclaw). This circumvents errors in non-interactive SSH sessions where the global PATH is often unavailable.

Optimized Asset Rendering: Switched to a native NSImageView engine on macOS to render GIF assets. This bypasses the strict WebKit sandbox restrictions on local file access and handles high-resolution asset scaling without display artifacts.

Rust-Powered Tunneling: The Windows version leverages the ssh2 library to manage tunnel mappings directly in memory, resulting in a significantly lower system footprint compared to traditional subprocess-based tunneling.

📜 Changelog (EN)

[v3.5.2]

Introduced the -T flag to disable remote PTY; Added official absolute path support; Migrated to a native NSImageView rendering engine.

[v3.5.1]

Corrected UI alignment via Flexbox; Implemented a strict node state-reset on startup; Polished Windows input field aesthetics.

[v3.5.0]

Integrated official CLI-based monitoring; Introduced the redesigned author information card; Optimized for macOS 26.0+ advanced animations.

[v3.0.0]

Established geek-centric visual standards; Implemented full system-level Keychain secure storage.

👨‍💻 关于作者 (About Author)

@Eyesslee

开发这个工具的初衷是追求视觉美感与底层技术的平衡。希望它能帮你从繁琐的运维指令中解脱出来，让隧道管理和实例监控变得更加简单、直观。

I built this tool with the philosophy that professional dev-ops utilities don't have to be visually uninspiring. I hope it helps you stay focused on what matters by making SSH tunnel and instance management as frictionless as possible.

⚖️ License

本项目遵循 MIT 开源协议 (Licensed under the MIT License).
