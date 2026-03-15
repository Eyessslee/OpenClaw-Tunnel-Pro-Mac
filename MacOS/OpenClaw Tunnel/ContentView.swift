import SwiftUI
import AppKit
import Combine
import Security

// MARK: - 0. 原生 GIF 渲染器 (🌟 彻底解决尺寸溢出问题)
struct GifImage: NSViewRepresentable {
    let name: String
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        // 🌟 核心：强制等比缩放，适应外层 Frame 尺寸，绝不撑破！
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        
        // 🌟 降低自身的尺寸优先级，绝对服从 SwiftUI 的 frame 约束
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.clear.cgColor
        
        if let url = Bundle.main.url(forResource: name, withExtension: "gif"),
           let data = try? Data(contentsOf: url),
           let image = NSImage(data: data) {
            imageView.image = image
        }
        return imageView
    }
    func updateNSView(_ nsView: NSImageView, context: Context) {}
}

// MARK: - 1. 安全存储引擎 (Keychain)
struct KeychainHelper {
    static let service = "com.openclaw.tunnel"
    enum Keys: String { case serverList = "servers_config" }
    static func save(_ string: String, for key: Keys) {
        let data = Data(string.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key.rawValue]
        SecItemDelete(query as CFDictionary)
        var newQuery = query; newQuery[kSecValueData as String] = data
        SecItemAdd(newQuery as CFDictionary, nil)
    }
    static func load(for key: Keys) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key.rawValue, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?; if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data { return String(data: data, encoding: .utf8) }
        return nil
    }
}

// MARK: - 2. 彩蛋引擎
struct EggEngine {
    static func random() -> String {
        guard let path = Bundle.main.path(forResource: "EasterEggs", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let jokes = dict["Jokes"] as? [String] else { return "正在通过 SSH 隧道守护您的数据安全。" }
        return jokes.randomElement() ?? "系统稳定运行中。"
    }
}

// MARK: - 3. 本地化字典
enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans", english = "en"
    var id: String { self.rawValue }
    var displayName: String { self == .simplifiedChinese ? "简体中文" : "English" }
}

struct LocaleMap {
    static func text(_ key: String, lang: AppLanguage) -> String {
        let table: [String: [AppLanguage: String]] = [
            "add_node": [.simplifiedChinese: "添加节点", .english: "Add Node"],
            "btn_connect": [.simplifiedChinese: "建立加密隧道", .english: "Establish Tunnel"],
            "btn_connecting": [.simplifiedChinese: "正在握手...", .english: "Synchronizing..."],
            "btn_disconnect": [.simplifiedChinese: "断开隧道连接", .english: "Disconnect"],
            "btn_quit": [.simplifiedChinese: "退出应用", .english: "Quit App"],
            "settings_lang": [.simplifiedChinese: "界面语言 / Language", .english: "Language / 界面语言"],
            "settings_refresh": [.simplifiedChinese: "监控刷新频率", .english: "Refresh Rate"],
            "edit_config": [.simplifiedChinese: "编辑环境配置", .english: "Edit Config"],
            "delete_node": [.simplifiedChinese: "删除节点", .english: "Delete Node"],
            "open_dashboard": [.simplifiedChinese: "进入控制台面板", .english: "Enter Dashboard"],
            "fetch_token": [.simplifiedChinese: "准备控制台鉴权", .english: "Prepare Auth"],
            "fetching_token": [.simplifiedChinese: "正在流式读取...", .english: "Reading Log..."],
            "restart_gateway": [.simplifiedChinese: "重启网关", .english: "Restart"],
            "restarting": [.simplifiedChinese: "正在重启...", .english: "Restarting..."],
            "kpi_monitor": [.simplifiedChinese: "监控面板", .english: "MONITOR"],
            "refresh_unit": [.simplifiedChinese: "分钟", .english: "min"],
            "refresh_in": [.simplifiedChinese: "后刷新", .english: "to refresh"],
            "cfg_title": [.simplifiedChinese: "节点设置", .english: "Node Settings"],
            "cfg_alias": [.simplifiedChinese: "节点别名", .english: "Alias"],
            "cfg_ip": [.simplifiedChinese: "服务器 IP", .english: "Host IP"],
            "cfg_user": [.simplifiedChinese: "用户名", .english: "User"],
            "cfg_pwd": [.simplifiedChinese: "SSH 密码", .english: "Password"],
            "cfg_port": [.simplifiedChinese: "本地映射端口", .english: "Local Port"],
            "cfg_extra": [.simplifiedChinese: "附加转发端口", .english: "Extra Ports"],
            "cfg_done": [.simplifiedChinese: "完成", .english: "Done"],
            "cfg_cancel": [.simplifiedChinese: "取消", .english: "Cancel"],
            "kpi_tokens": [.simplifiedChinese: "Token", .english: "Token"],
            "kpi_links": [.simplifiedChinese: "活跃连接", .english: "Links"],
            "kpi_reqs": [.simplifiedChinese: "请求总量", .english: "Reqs"]
        ]
        return table[key]?[lang] ?? key
    }
}

struct ServerProfile: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var ip: String = ""
    var user: String = "root"
    var pass: String = ""
    var gatewayPort: String = "18789"
    var extraPorts: String = ""
}

// MARK: - 4. 主视图
struct ContentView: View {
    @AppStorage("serversJSON") private var serversJSON: String = "[]"
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .simplifiedChinese
    @AppStorage("refreshInterval") private var refreshInterval: Int = 600
    
    @State private var servers: [ServerProfile] = []
    @State private var isEditingSettings: Bool = false
    @State private var isShowingAuthor: Bool = false // 🌟 作者弹窗状态
    @State private var isEditingServer: Bool = false
    @State private var isRestarting: Bool = false
    @State private var draftProfile: ServerProfile = ServerProfile()
    
    @StateObject private var oaManager = OAManager()
    private let tunnelManager = SSHTunnelManager()
    
    @State private var connectedServers: Set<String> = []
    @State private var connectingServers: Set<String> = []
    @State private var serverTokens: [String: String] = [:]
    @State private var fetchingTokens: Set<String> = []
    
    @State private var debugLogs: String = ""
    @State private var currentEgg: String = "系统状态：就绪。"
    @State private var heartbeatPhase: Bool = false
    @State private var refreshCountdown: Int = 600
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    let peacockBlue = Color(red: 0/255, green: 135/255, blue: 146/255)
    let systemBrightRed = Color(red: 255/255, green: 75/255, blue: 75/255)
    let darkTeal = Color(red: 5/255, green: 18/255, blue: 14/255)

    var body: some View {
        ZStack {
            darkTeal.ignoresSafeArea()
            BackgroundAtmosphere(themeColor: peacockBlue.opacity(0.12))
            Rectangle().fill(.ultraThinMaterial).opacity(0.65).ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView()
                
                ScrollView {
                    VStack(spacing: 0) {
                        if let server = servers.first, servers.count <= 1 {
                            mainUtilityArea(server).padding(.top, 40)
                        } else {
                            multiServerListView()
                        }
                    }
                }
                footerUtilityBar()
            }
            .padding(.horizontal, 25)
            
            if isEditingSettings { settingsPopover() }
            if isShowingAuthor { authorPopover() } // 🌟 作者弹窗
        }
        .frame(width: 380, height: 620)
        .onAppear { setupWindow(); loadAllConfigs() }
        .sheet(isPresented: $isEditingServer) { serverEditorView().frame(width: 350, height: 550) }
        .onReceive(refreshTimer) { _ in handleRefreshLogic() }
    }

    private func executeRemoteTokenGrab(for server: ServerProfile) {
        withAnimation { _ = fetchingTokens.insert(server.id) }
        let tokenCmd = "bash -lc 'openclaw dashboard'"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let expectScript = """
            set timeout 10
            spawn /usr/bin/ssh -o StrictHostKeyChecking=no \(server.user)@\(server.ip) {\(tokenCmd)}
            expect {
                "*assword:*" { send "\(server.pass)\\r"; exp_continue }
                eof
            }
            """
            process.executableURL = URL(fileURLWithPath: "/usr/bin/expect")
            process.arguments = ["-c", expectScript]
            
            let pipe = Pipe()
            process.standardOutput = pipe; process.standardError = pipe
            let outHandle = pipe.fileHandleForReading
            outHandle.readabilityHandler = { pipe in
                if let line = String(data: pipe.availableData, encoding: .utf8), !line.isEmpty {
                    DispatchQueue.main.async { self.appendLog(line) }
                }
            }
            try? process.run(); process.waitUntilExit(); outHandle.readabilityHandler = nil
            DispatchQueue.main.async { withAnimation { _ = fetchingTokens.remove(server.id) } }
        }
    }

    private func scanLogsForToken(serverID: String) {
        let pattern = "token=([a-fA-F0-9]{32,})"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsString = debugLogs as NSString
            let results = regex.matches(in: debugLogs, options: [], range: NSMakeRange(0, nsString.length))
            if let lastMatch = results.last {
                let tokenValue = nsString.substring(with: lastMatch.range(at: 1))
                if serverTokens[serverID] != tokenValue {
                    DispatchQueue.main.async { self.serverTokens[serverID] = tokenValue }
                }
            }
        }
    }

    private func dashboardLogicButton(for server: ServerProfile) -> some View {
        let token = serverTokens[server.id] ?? ""
        let isFetching = fetchingTokens.contains(server.id)
        let hasToken = !token.isEmpty
        
        return Button(action: {
            if hasToken { openDashboard(for: server) } else { executeRemoteTokenGrab(for: server) }
        }) {
            HStack {
                if isFetching {
                    ProgressView().controlSize(.small).scaleEffect(0.8).padding(.trailing, 4)
                    Text(LocaleMap.text("fetching_token", lang: appLanguage)).lineLimit(1).minimumScaleFactor(0.8)
                } else {
                    Image(systemName: hasToken ? "safari.fill" : "key.viewfinder")
                    Text(LocaleMap.text(hasToken ? "open_dashboard" : "fetch_token", lang: appLanguage)).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(hasToken ? .white : peacockBlue)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(hasToken ? peacockBlue : peacockBlue.opacity(0.12))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(peacockBlue, lineWidth: hasToken ? 0 : 1))
        }.buttonStyle(.plain).disabled(isFetching)
    }

    private func mainUtilityArea(_ server: ServerProfile) -> some View {
        let isConnected = connectedServers.contains(server.id)
        let isConnecting = connectingServers.contains(server.id)
        return VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: isConnected ? "shield.fill" : "server.rack").font(.system(size: 64, weight: .ultraLight)).foregroundColor(isConnected ? .green : peacockBlue).scaleEffect(isConnected ? (heartbeatPhase ? 1.05 : 1.0) : 1.0).animation(isConnected ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default, value: heartbeatPhase)
                VStack(spacing: 4) { Text(server.name.isEmpty ? "openclaw" : server.name).font(.system(size: 36, weight: .heavy, design: .rounded)).foregroundColor(.white); Text(server.ip).font(.system(size: 16, weight: .medium, design: .monospaced)).foregroundColor(.white.opacity(0.4)) }
            }
            if isConnected {
                VStack(spacing: 18) {
                    Text(currentEgg).font(.system(size: 11, weight: .medium)).foregroundColor(peacockBlue.opacity(0.7)).italic().transition(.opacity)
                    PureDashboardView(metrics: oaManager.metrics[server.id] ?? ServerMetrics(), lang: appLanguage, countdown: refreshCountdown) { forceRefresh(for: server) }
                    
                    GeometryReader { geo in
                        let spacing: CGFloat = 15
                        let cardWidth = (geo.size.width - spacing * 2) / 3
                        
                        HStack(spacing: spacing) {
                            dashboardLogicButton(for: server)
                                .frame(width: cardWidth * 2 + spacing)
                            
                            Button(action: { performRemoteRestart(for: server) }) {
                                HStack(spacing: 4) {
                                    if isRestarting { ProgressView().controlSize(.small).scaleEffect(0.7) }
                                    else { Image(systemName: "arrow.clockwise.circle.fill") }
                                    Text(LocaleMap.text(isRestarting ? "restarting" : "restart_gateway", lang: appLanguage))
                                        .lineLimit(1).minimumScaleFactor(0.6)
                                }
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.orange)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.orange.opacity(0.12)).cornerRadius(8)
                            }
                            .buttonStyle(.plain).disabled(isRestarting)
                            .frame(width: cardWidth)
                        }
                    }.frame(height: 38)
                    
                }.transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
            Button(action: { isConnected ? disconnectServer(id: server.id, profile: server) : connectServer(profile: server) }) {
                HStack { if isConnecting { ProgressView().controlSize(.small).padding(.trailing, 5) }; Text(LocaleMap.text(isConnecting ? "btn_connecting" : (isConnected ? "btn_disconnect" : "btn_connect"), lang: appLanguage)).font(.system(size: 15, weight: .bold)) }
                .frame(width: 220, height: 48).background(isConnected ? systemBrightRed.opacity(0.8) : peacockBlue).foregroundColor(.white).cornerRadius(24)
            }.buttonStyle(SpringButtonStyle()).disabled(isConnecting)
            if !isConnected {
                HStack(spacing: 25) {
                    Button(LocaleMap.text("edit_config", lang: appLanguage)) { draftProfile = server; isEditingServer = true }.font(.system(size: 12)).foregroundColor(.white.opacity(0.4)).buttonStyle(.plain)
                    Button(LocaleMap.text("delete_node", lang: appLanguage)) { deleteServer(server) }.font(.system(size: 12)).foregroundColor(systemBrightRed.opacity(0.8)).buttonStyle(.plain)
                }
            }
        }.onAppear { heartbeatPhase = true }
    }

    private func multiServerListView() -> some View {
        VStack(spacing: 14) {
            ForEach(servers) { server in
                let isConnected = connectedServers.contains(server.id)
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) { Text(server.name.isEmpty ? "openclaw" : server.name).font(.title3).bold(); Text(server.ip).font(.caption).opacity(0.5) }
                        Spacer()
                        if !isConnected {
                            Button(action: { draftProfile = server; isEditingServer = true }) { Image(systemName: "pencil") }.buttonStyle(.plain).padding(.trailing, 8).opacity(0.5)
                            Button(action: { deleteServer(server) }) { Image(systemName: "trash") }.buttonStyle(.plain).padding(.trailing, 12).foregroundColor(systemBrightRed.opacity(0.7))
                        }
                        Button(action: { isConnected ? disconnectServer(id: server.id, profile: server) : connectServer(profile: server) }) {
                            HStack(spacing: 6) { if connectingServers.contains(server.id) { ProgressView().controlSize(.small).scaleEffect(0.6) }; Text(LocaleMap.text(isConnected ? "btn_disconnect" : "btn_connect", lang: appLanguage)) }
                        }.buttonStyle(.borderedProminent).tint(isConnected ? systemBrightRed : peacockBlue).controlSize(.small).disabled(connectingServers.contains(server.id))
                    }.padding()
                    if isConnected {
                        Divider().opacity(0.3)
                        VStack(spacing: 15) {
                            PureDashboardView(metrics: oaManager.metrics[server.id] ?? ServerMetrics(), lang: appLanguage, countdown: refreshCountdown) { forceRefresh(for: server) }
                            
                            GeometryReader { geo in
                                let spacing: CGFloat = 15
                                let cardWidth = (geo.size.width - spacing * 2) / 3
                                HStack(spacing: spacing) {
                                    dashboardLogicButton(for: server)
                                        .frame(width: cardWidth * 2 + spacing)
                                    Button(action: { performRemoteRestart(for: server) }) {
                                        HStack(spacing: 4) {
                                            if isRestarting { ProgressView().controlSize(.small).scaleEffect(0.7) }
                                            else { Image(systemName: "arrow.clockwise.circle.fill") }
                                            Text(LocaleMap.text(isRestarting ? "restarting" : "restart_gateway", lang: appLanguage)).lineLimit(1).minimumScaleFactor(0.6)
                                        }
                                        .font(.system(size: 11, weight: .bold)).foregroundColor(.orange)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.orange.opacity(0.15)).cornerRadius(8)
                                    }
                                    .buttonStyle(.plain).disabled(isRestarting).frame(width: cardWidth)
                                }
                            }.frame(height: 36)
                            
                        }.padding().transition(.move(edge: .top).combined(with: .opacity))
                    }
                }.background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.05)))
            }
        }.padding(.vertical, 20)
    }

    private func openDashboard(for server: ServerProfile) {
        let port = server.gatewayPort.isEmpty ? "18789" : server.gatewayPort
        let token = serverTokens[server.id] ?? ""
        let urlStr = "http://127.0.0.1:\(port)/#token=\(token)"
        if let url = URL(string: urlStr) { NSWorkspace.shared.open(url) }
    }
    private func appendLog(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanText.isEmpty {
            debugLogs += "\(cleanText)\n"
            if let activeID = servers.first?.id { scanLogsForToken(serverID: activeID) }
        }
    }
    private func loadAllConfigs() {
        if let json = KeychainHelper.load(for: .serverList), let data = json.data(using: .utf8), let decoded = try? JSONDecoder().decode([ServerProfile].self, from: data) { servers = decoded }
        else if !serversJSON.isEmpty, let data = serversJSON.data(using: .utf8), let decoded = try? JSONDecoder().decode([ServerProfile].self, from: data) { servers = decoded; saveAllConfigs() }
        refreshCountdown = refreshInterval
    }
    private func saveAllConfigs() { if let data = try? JSONEncoder().encode(servers), let json = String(data: data, encoding: .utf8) { KeychainHelper.save(json, for: .serverList) } }
    private func handleRefreshLogic() { guard !connectedServers.isEmpty && connectingServers.isEmpty else { return }; if refreshCountdown > 0 { refreshCountdown -= 1 } else { if let s = servers.first(where: { connectedServers.contains($0.id) }) { forceRefresh(for: s) } } }
    private func forceRefresh(for server: ServerProfile) { oaManager.fetchMetrics(id: server.id, host: server.ip, user: server.user, pass: server.pass); refreshCountdown = refreshInterval; withAnimation { currentEgg = EggEngine.random() } }
    private func connectServer(profile: ServerProfile) {
        let id = profile.id; withAnimation { _ = connectingServers.insert(id) }
        tunnelManager.connectAndListen(id: id, ip: profile.ip, user: profile.user, pass: profile.pass, localPort: profile.gatewayPort, remotePort: "18789", extraPorts: profile.extraPorts.components(separatedBy: ","), onTokenReceived: { _ in })
        { success, _ in DispatchQueue.main.async { withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { _ = connectingServers.remove(id); if success { connectedServers.insert(id); currentEgg = EggEngine.random(); refreshCountdown = refreshInterval } }; if success { oaManager.fetchMetrics(id: id, host: profile.ip, user: profile.user, pass: profile.pass) } } }
    }
    private func disconnectServer(id: String, profile: ServerProfile) { withAnimation { _ = connectedServers.remove(id) }; tunnelManager.disconnect(id: id, localPort: profile.gatewayPort, extraPorts: profile.extraPorts.components(separatedBy: ",")) }
    private func setupWindow() { DispatchQueue.main.async { if let window = NSApplication.shared.windows.first { window.center(); window.standardWindowButton(.zoomButton)?.isEnabled = false } } }
    private func performRemoteRestart(for server: ServerProfile) {
        withAnimation { isRestarting = true }; let restartCmd = "bash -lc 'echo \(server.pass) | sudo -S systemctl restart openclaw-gateway'"
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process(); let expectScript = "set timeout 20\nspawn /usr/bin/ssh -o StrictHostKeyChecking=no \(server.user)@\(server.ip) {\(restartCmd)}\nexpect {\n \"assword:\" { send \"\(server.pass)\\r\"; expect eof }\n eof\n}"
            process.executableURL = URL(fileURLWithPath: "/usr/bin/expect"); process.arguments = ["-c", expectScript]; try? process.run(); process.waitUntilExit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { isRestarting = false }; forceRefresh(for: server) }
        }
    }
    
    // MARK: - 构建与设置
    private func headerView() -> some View { HStack { Text("OpenClaw Tunnel Pro").font(.system(size: 11, weight: .black)).foregroundColor(peacockBlue); Spacer(); if !(servers.count == 1 && connectedServers.contains(servers[0].id)) { Button(action: prepareNewServer) { HStack(spacing: 4) { Image(systemName: "plus.circle.fill"); Text(LocaleMap.text("add_node", lang: appLanguage)) }.font(.system(size: 12, weight: .bold)).foregroundColor(peacockBlue) }.buttonStyle(.plain) } }.padding(.vertical, 10) }
    
    // 🌟 左下角工具栏：并排图标
    private func footerUtilityBar() -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: { withAnimation { isShowingAuthor.toggle(); isEditingSettings = false } }) {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 16)).foregroundColor(.white).frame(width: 32, height: 32).background(Circle().fill(.white.opacity(isShowingAuthor ? 0.3 : 0.15)))
            }.buttonStyle(.plain)
            
            Button(action: { withAnimation { isEditingSettings.toggle(); isShowingAuthor = false } }) {
                Image(systemName: "gearshape.fill").font(.system(size: 16)).foregroundColor(.white).frame(width: 32, height: 32).background(Circle().fill(.white.opacity(isEditingSettings ? 0.3 : 0.15)))
            }.buttonStyle(.plain)
            
            Spacer()
            Text("v3.5.2@Eyesslee").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(.white.opacity(0.2))
            Spacer()
            Button(action: { NSApplication.shared.terminate(nil) }) { Text(LocaleMap.text("btn_quit", lang: appLanguage)).font(.system(size: 12, weight: .bold)).foregroundColor(systemBrightRed) }.buttonStyle(.plain)
        }.frame(height: 40).padding(.bottom, 10)
    }
    
    // 🌟 作者名片弹窗 (加入 clipShape 以裁剪圆角)
    private func authorPopover() -> some View {
        Group {
            Color.black.opacity(0.01).onTapGesture { withAnimation { isShowingAuthor = false } }
            HStack(spacing: 15) {
                GifImage(name: "avatar")
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12)) // 🌟 强力裁切，防越界
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(peacockBlue, lineWidth: 2))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("@Eyesslee")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(peacockBlue)
                    Text("你也可以叫我渣男小李")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            .position(x: 165, y: 490)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    private func settingsPopover() -> some View { Group { Color.black.opacity(0.01).onTapGesture { withAnimation { isEditingSettings = false } }; VStack(alignment: .leading, spacing: 15) { VStack(alignment: .leading, spacing: 6) { Text(LocaleMap.text("settings_lang", lang: appLanguage)).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary); Picker("", selection: $appLanguage) { ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) } }.pickerStyle(.radioGroup).labelsHidden() }; Divider().opacity(0.2); VStack(alignment: .leading, spacing: 6) { Text(LocaleMap.text("settings_refresh", lang: appLanguage)).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary); Picker("", selection: $refreshInterval) { Text("5 \(LocaleMap.text("refresh_unit", lang: appLanguage))").tag(300); Text("10 \(LocaleMap.text("refresh_unit", lang: appLanguage))").tag(600); Text("15 \(LocaleMap.text("refresh_unit", lang: appLanguage))").tag(900); Text("30 \(LocaleMap.text("refresh_unit", lang: appLanguage))").tag(1800) }.pickerStyle(.menu).onChange(of: refreshInterval) { _, n in refreshCountdown = n } } }.padding(18).frame(width: 200).background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1)).shadow(radius: 10).position(x: 130, y: 450).transition(.scale(scale: 0.9).combined(with: .opacity)) } }
    
    private func prepareNewServer() { var new = ServerProfile(); let used = servers.compactMap { Int($0.gatewayPort) }; var target = 18789; while used.contains(target) { target += 1 }; new.gatewayPort = String(target); self.draftProfile = new; self.isEditingServer = true }
    private func saveServer() { if let idx = servers.firstIndex(where: { $0.id == draftProfile.id }) { servers[idx] = draftProfile } else { servers.append(draftProfile) }; saveAllConfigs(); isEditingServer = false }
    private func deleteServer(_ s: ServerProfile) { disconnectServer(id: s.id, profile: s); servers.removeAll(where: { $0.id == s.id }); saveAllConfigs() }
    private func serverEditorView() -> some View { VStack(spacing: 0) { HStack { Button(LocaleMap.text("cfg_cancel", lang: appLanguage)) { isEditingServer = false }.foregroundColor(.secondary); Spacer(); Text(LocaleMap.text("cfg_title", lang: appLanguage)).font(.headline); Spacer(); Button(LocaleMap.text("cfg_done", lang: appLanguage)) { saveServer() }.foregroundColor(peacockBlue).bold() }.padding(25).buttonStyle(.plain); ScrollView { VStack(spacing: 18) { ConfigField(title: LocaleMap.text("cfg_alias", lang: appLanguage), placeholder: "例如：北京金融区", text: $draftProfile.name); ConfigField(title: LocaleMap.text("cfg_ip", lang: appLanguage), placeholder: "81.70.x.x", text: $draftProfile.ip); ConfigField(title: LocaleMap.text("cfg_user", lang: appLanguage), placeholder: "root", text: $draftProfile.user); VStack(alignment: .leading, spacing: 6) { Text(LocaleMap.text("cfg_pwd", lang: appLanguage)).font(.system(size: 9, weight: .bold)).opacity(0.4); SecureField("", text: $draftProfile.pass).textFieldStyle(.plain).padding(10).background(.white.opacity(0.05)).cornerRadius(8) }; Divider().opacity(0.2).padding(.vertical, 5); ConfigField(title: LocaleMap.text("cfg_port", lang: appLanguage), placeholder: "18789", text: $draftProfile.gatewayPort); ConfigField(title: LocaleMap.text("cfg_extra", lang: appLanguage), placeholder: "例如 8080:80", text: $draftProfile.extraPorts) }.padding(.horizontal, 25).padding(.bottom, 30) } }.background(Color(NSColor.windowBackgroundColor)) }
}

// MARK: - 🚀 辅助样式组件
struct PureDashboardView: View {
    var metrics: ServerMetrics; var lang: AppLanguage; var countdown: Int; var onRefresh: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(LocaleMap.text("kpi_monitor", lang: lang)).font(.system(size: 9, weight: .black)).opacity(0.3)
                Spacer(); HStack(spacing: 3) { Text(String(format: "%02d:%02d", countdown / 60, countdown % 60)).foregroundColor(Color(red: 0/255, green: 135/255, blue: 146/255)); Text(LocaleMap.text("refresh_in", lang: lang)) }.font(.system(size: 9, weight: .bold)).opacity(0.5)
                Button(action: onRefresh) { Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.5)) }.buttonStyle(.plain)
            }
            HStack(spacing: 15) {
                PureKPICard(title: LocaleMap.text("kpi_tokens", lang: lang), value: metrics.totalTokens, color: .yellow)
                PureKPICard(title: LocaleMap.text("kpi_links", lang: lang), value: metrics.activeLinks, color: .green)
                PureKPICard(title: LocaleMap.text("kpi_reqs", lang: lang), value: metrics.requestCount, color: .blue)
            }
        }
    }
}
struct SpringButtonStyle: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.scaleEffect(configuration.isPressed ? 0.94 : 1.0).animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed) } }
struct BackgroundAtmosphere: View { let themeColor: Color; var body: some View { ZStack { RadialGradient(colors: [themeColor, .clear], center: .center, startRadius: 10, endRadius: 500).opacity(0.4); Canvas { context, size in for _ in 0..<25 { let x = Double.random(in: 0...size.width); let y = Double.random(in: 0...size.height); context.opacity = Double.random(in: 0.05...0.2); context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(.white)) } } } } }
struct ConfigField: View { var title: String; var placeholder: String; @Binding var text: String; var body: some View { VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 9, weight: .bold)).opacity(0.4); TextField(placeholder, text: $text).textFieldStyle(.plain).padding(10).background(.white.opacity(0.05)).cornerRadius(8) } } }
struct PureKPICard: View { var title: String; var value: String; var color: Color; var body: some View { VStack(spacing: 4) { Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(color); Text(title).font(.system(size: 9, weight: .bold)).opacity(0.5) }.frame(maxWidth: .infinity).padding(.vertical, 8).background(.white.opacity(0.05)).cornerRadius(8) } }
