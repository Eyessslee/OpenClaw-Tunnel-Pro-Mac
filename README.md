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

💾 安装与运行说明

下载安装包：从仓库右侧的 Releases 页面下载最新的 .dmg (macOS) 或 .exe (Windows) 文件。

macOS 安全提示：由于应用未经过 Apple 开发者签名，初次打开时系统会提示“无法验证开发者”。

解决办法：在“访达 (Finder)”中找到应用，右键点击并选择“打开”，在弹出的窗口中再次点击“打开”即可。


📜 进化史 (Changelog)

[v3.5.2]

引入 -T 参数禁用远程 PTY，修复超长数据截断问题；增加官方绝对路径支持；改用原生 NSImageView 渲染引擎。

[v3.5.1]

引入 Flexbox 约束修正 Windows 按钮对齐；启动时强制重置节点激活态，修复 UI 幽灵状态；物理级抹除 Windows 输入框白框。

[v3.5.0]

接入官方 CLI 统计，实现实时 Token、Links、Reqs 监测；新增作者信息模块与 GIF 动画支持；适配 macOS 26.0+ 高级动效。

[v1.0.0 - v3.0.0]

完成基础 SSH 隧道建立、多节点持久化管理、确立“孔雀蓝”视觉规范及全面接入系统级加密存储。

👨‍💻 关于作者 (About Author)

@Eyesslee

开发这个工具的初衷是追求视觉美感与底层技术的平衡。希望它能帮你从繁琐的运维指令中解脱出来，让隧道管理和实例监控变得更加简单、直观。

⚖️ 免责声明 (Disclaimer)

本项目及相关编译产物（App）仅供个人技术测试、交流与娱乐使用。

请勿将本工具用于任何非法用途或生产环境。

开发者不对因使用本工具导致的任何数据丢失、安全问题或系统故障承担法律责任。

本项目遵循 MIT 开源协议。

<h2 id="introduction-en">🇺🇸 English Introduction</h2>

Hello! I’d like to share a small utility I’ve been working on: OpenClaw Tunnel Pro.

I originally developed this tool to scratch my own itch—specifically the friction of constantly switching SSH tunnels and manually checking metrics while managing OpenClaw instances. My goal was to build a solution that combines a fluid, native app experience with robust, system-level security for server credentials. Now at v3.5.2, it’s stable enough for sharing with anyone in the community.

🌟 Core Features

Real-time Observability: captures Token consumption (24h incremental), active session counts, and total request volume directly via SSH.

Cryptographically Secure: Credentials are managed via macOS Keychain or system-native encrypted stores. No plaintext configs are kept.

Intelligent Lifecycle Management: Effortlessly switch between multiple node profiles with built-in port-collision avoidance and automatic reconnection.

Native Aesthetic Experience: Designed with a platform-first mindset, supporting macOS physical effects and Windows Mica translucent design.

🛠️ Technical Highlights

Data Integrity via PTY Control: Uses the -T flag in macOS to disable remote PTY, preventing JSON truncation by terminal auto-line-wrapping (\r\n).

Environment-Aware Execution: Implemented support for absolute CLI paths to circumvent "command not found" errors in non-interactive SSH sessions.

Optimized Asset Rendering: Switched to a native NSImageView engine on macOS to bypass sandboxing restrictions on local GIF file access.

Rust-Powered Tunneling: The Windows version leverages the ssh2 library for high-efficiency, in-memory tunnel mapping.

💾 Installation & Usage

Download: Get the latest .dmg or .app from the Releases section.

macOS Security: Since this app is not signed by a paid Apple developer account, you might see a "cannot be verified" warning.

Fix: Right-click the app icon in Finder and select "Open", then confirm in the popup.


📜 Changelog (EN)

[v3.5.2]

Introduced the -T flag to disable remote PTY; Added official absolute path support; Migrated to a native NSImageView rendering engine.

[v3.5.1]

Corrected UI alignment via Flexbox; Implemented a strict node state-reset on startup.

👨‍💻 About Author

@Eyesslee

I built this tool with the philosophy that professional dev-ops utilities don't have to be visually uninspiring. I hope it helps you stay focused on what matters by making tunnel management as frictionless as possible.

⚖️ Disclaimer

This project and its binaries are intended for personal testing, technical exchange, and entertainment purposes ONLY.

Do not use this tool for any illegal activities or mission-critical production environments.

The developer is not responsible for any data loss, security breaches, or system failures resulting from the use of this tool.

Licensed under the MIT License.
