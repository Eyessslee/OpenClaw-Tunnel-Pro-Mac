import Foundation
import SwiftUI
import Combine

struct ServerMetrics {
    var totalTokens: String = "--"
    var activeLinks: String = "--"
    var requestCount: String = "--"
    var isFetching: Bool = false
}

class OAManager: ObservableObject {
    @Published var metrics: [String: ServerMetrics] = [:]
    
    func fetchAllMetrics(servers: [(id: String, host: String, user: String, pass: String)]) {
        for s in servers { fetchMetrics(id: s.id, host: s.host, user: s.user, pass: s.pass) }
    }
    
    func fetchMetrics(id: String, host: String, user: String, pass: String) {
        DispatchQueue.main.async {
            if self.metrics[id] == nil { self.metrics[id] = ServerMetrics() }
            self.metrics[id]?.isFetching = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let openclawPath = "/root/.nvm/versions/node/v22.22.1/bin/openclaw"
            let usageCmd = "\(openclawPath) sessions --all-agents --json 2>/dev/null"
            let listCmd = "\(openclawPath) status --json 2>/dev/null"
            let combinedCmd = "bash -lc '\(usageCmd) ; echo DATA_BOUNDARY ; \(listCmd)'"
            
            let safePass = pass.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "$", with: "\\$")
                .replacingOccurrences(of: "[", with: "\\[")
                .replacingOccurrences(of: "]", with: "\\]")
            
            let process = Process()
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            // 🌟 终极修复：增加 -T 参数，彻底禁用远程伪终端！杜绝自动换行截断 JSON！
            let expectScript = """
            set timeout 30
            spawn /usr/bin/ssh -T -o StrictHostKeyChecking=no \(user)@\(host) {\(combinedCmd)}
            expect {
                "assword:" { 
                    send "\(safePass)\\r"
                    exp_continue
                }
                eof {
                    exit 0
                }
            }
            """
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/expect")
            process.arguments = ["-c", expectScript]
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    self.parse(output, for: id)
                }
            } catch { print("Fetch Error: \(error.localizedDescription)") }
            DispatchQueue.main.async { self.metrics[id]?.isFetching = false }
        }
    }
    
    private func parse(_ output: String, for id: String) {
        let parts = output.components(separatedBy: "DATA_BOUNDARY")
        
        func extractJSON(from str: String) -> [String: Any]? {
            guard let start = str.firstIndex(of: "{"),
                  let end = str.lastIndex(of: "}") else { return nil }
            if start < end {
                let jsonStr = String(str[start...end])
                if let data = jsonStr.data(using: .utf8) {
                    do {
                        return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    } catch {
                        print("❌ JSON 解析失败: \(error)")
                    }
                }
            }
            return nil
        }
        
        let jsonParts = parts.compactMap { extractJSON(from: $0) }
        
        var dict1: [String: Any]? = nil
        var dict2: [String: Any]? = nil
        
        for dict in jsonParts {
            if dict.keys.contains("allAgents") || dict["sessions"] is [[String: Any]] {
                dict1 = dict
            } else if dict.keys.contains("channelSummary") || dict.keys.contains("gateway") {
                dict2 = dict
            }
        }
        
        var tokenSum: Int = 0
        var requestCount: Int = 0
        var activeLinks: Int = 0
        
        // 1. 解析请求数与 Token (过滤近24小时)
        if let d1 = dict1 {
            requestCount = (d1["count"] as? NSNumber)?.intValue ?? 0
            if let sessions = d1["sessions"] as? [[String: Any]] {
                let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
                let dayMs: Int64 = 24 * 3600 * 1000
                let threshold = nowMs - dayMs
                
                for s in sessions {
                    let updatedAt = (s["updatedAt"] as? NSNumber)?.int64Value ?? 0
                    if updatedAt >= threshold {
                        tokenSum += (s["totalTokens"] as? NSNumber)?.intValue ?? 0
                    }
                }
            }
        }
        
        // 2. 解析 Status 活跃连接 (🌟 智能过滤掉缩进的详细说明项)
        if let d2 = dict2 {
            if let channels = d2["channelSummary"] as? [String] {
                // 过滤掉以空格开头的子项（如 "  - default"），只保留真正的频道主项
                activeLinks = channels.filter { !$0.hasPrefix(" ") && !$0.hasPrefix("\t") }.count
            }
        }
        
        // 3. 格式化 Token 显示
        let tokenDisplay: String
        if tokenSum < 1000 {
            tokenDisplay = "\(tokenSum)"
        } else if tokenSum < 1_000_000 {
            tokenDisplay = String(format: "%.1fK", Double(tokenSum) / 1000.0)
        } else {
            tokenDisplay = String(format: "%.1fM", Double(tokenSum) / 1_000_000.0)
        }
        
        DispatchQueue.main.async {
            var m = self.metrics[id] ?? ServerMetrics()
            m.totalTokens = (tokenSum == 0 && requestCount == 0) ? "0" : tokenDisplay
            m.activeLinks = "\(activeLinks)"
            m.requestCount = "\(requestCount)"
            self.metrics[id] = m
        }
    }
}

// MARK: - 纯粹的 UI 渲染组件
struct KPIDashboardView: View {
    var serverName: String; var metrics: ServerMetrics; var onRefresh: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            KPICard(icon: "bolt.fill", color: .yellow, title: "Tokens", value: metrics.totalTokens)
            KPICard(icon: "waveform", color: .green, title: "Links", value: metrics.activeLinks)
            KPICard(icon: "tray", color: .blue, title: "Requests", value: metrics.requestCount)
        }
    }
}

struct KPICard: View {
    var icon: String; var color: Color; var title: String; var value: String
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 10))
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.system(size: 8)).opacity(0.4)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10).background(.white.opacity(0.1)).cornerRadius(12)
    }
}
