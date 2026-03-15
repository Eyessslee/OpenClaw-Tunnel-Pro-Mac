import Foundation

class SSHTunnelManager {
    private var processes: [String: Process] = [:]
    
    // 🚀 核心改进：增加 remoteGatewayPort 参数，默认为 18789
    func connectAndListen(id: String, ip: String, user: String, pass: String, localPort: String, remotePort: String = "18789", extraPorts: [String], onTokenReceived: @escaping (String) -> Void, completion: @escaping (Bool, String?) -> Void) {
        
        disconnect(id: id, localPort: localPort, extraPorts: extraPorts)
        
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        let lPort = localPort.isEmpty ? "18789" : localPort
        let rPort = remotePort.isEmpty ? "18789" : remotePort
        
        // 🎯 关键逻辑：本地端口(lPort) 映射到 远程127.0.0.1的远程端口(rPort)
        var sshCommand = "/usr/bin/ssh -o StrictHostKeyChecking=no -L \(lPort):127.0.0.1:\(rPort)"
        
        // 附加端口映射（如 19000 等，通常也是 1:1 映射）
        for ep in extraPorts where !ep.isEmpty {
            sshCommand += " -L \(ep):127.0.0.1:\(ep)"
        }
        
        sshCommand += " \(user)@\(ip) \"bash -lc 'openclaw dashboard; sleep 86400'\""
        
        let expectScript = """
        set timeout -1
        spawn \(sshCommand)
        expect {
            "yes/no" { send "yes\\r"; exp_continue }
            "assword:" { send "\(pass)\\r"; expect eof }
            eof
        }
        """
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/expect")
        process.arguments = ["-c", expectScript]
        processes[id] = process
        
        do {
            try process.run()
            DispatchQueue.global().asyncAfter(deadline: .now() + 4.0) {
                if self.processes[id]?.isRunning == true {
                    completion(true, nil)
                } else {
                    completion(false, "隧道启动失败，请检查本地端口 \(lPort) 是否被其他 App 占用。")
                }
            }
        } catch {
            completion(false, "系统错误: \(error.localizedDescription)")
        }
    }
    
    func disconnect(id: String, localPort: String, extraPorts: [String]) {
        if let p = processes[id], p.isRunning { p.terminate() }
        processes.removeValue(forKey: id)
        
        let lPort = localPort.isEmpty ? "18789" : localPort
        var allPorts = [lPort]
        allPorts.append(contentsOf: extraPorts.filter { !$0.isEmpty })
        let portString = allPorts.joined(separator: ",")
        
        let cleanup = Process()
        cleanup.executableURL = URL(fileURLWithPath: "/bin/sh")
        cleanup.arguments = ["-c", "lsof -ti :\(portString) | xargs kill -9 2>/dev/null"]
        try? cleanup.run()
        cleanup.waitUntilExit()
    }
    
    func disconnectAll(serverConfigs: [(id: String, lPort: String, exPorts: [String])]) {
        for config in serverConfigs {
            disconnect(id: config.id, localPort: config.lPort, extraPorts: config.exPorts)
        }
    }

    private func extractToken(from rawText: String) -> String? {
        let pattern = "token=([a-fA-F0-9]{30,})"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: rawText, options: [], range: NSRange(location: 0, length: rawText.count)) {
            return (rawText as NSString).substring(with: match.range(at: 1))
        }
        return nil
    }
}
