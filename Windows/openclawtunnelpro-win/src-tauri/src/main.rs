#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::{command, Emitter, AppHandle};
use ssh2::Session;
use std::net::{TcpStream, TcpListener, ToSocketAddrs};
use std::io::{Read, Write};
use regex::Regex;
use std::thread;
use std::time::Duration;
use std::process::Command;
use std::sync::{Arc, Mutex, OnceLock};
use std::sync::atomic::{AtomicBool, Ordering};
use std::collections::HashMap;

static ACTIVE_TUNNELS: OnceLock<Mutex<HashMap<u16, Arc<AtomicBool>>>> = OnceLock::new();

fn get_tunnels() -> &'static Mutex<HashMap<u16, Arc<AtomicBool>>> {
    ACTIVE_TUNNELS.get_or_init(|| Mutex::new(HashMap::new()))
}

// 🌟 核心杀招：真实后台指标获取 (方案3：CLI + JSON解析)
#[command]
async fn get_dynamic_metrics(ip: String, user: String, pass: String) -> Result<(String, u32, u32), String> {
    let tcp = TcpStream::connect(format!("{}:22", &ip)).map_err(|e| format!("TCP异常: {}", e))?;
    let mut sess = Session::new().map_err(|e| e.to_string())?;
    sess.set_tcp_stream(tcp);
    sess.set_timeout(8000); // 8秒超时，防止因网络波动阻塞 UI
    sess.handshake().map_err(|e| format!("握手失败: {}", e))?;
    sess.userauth_password(&user, &pass).map_err(|_| "认证失败".to_string())?;

    // 1. 获取 sessions 列表及 Token 消耗
    let mut ch1 = sess.channel_session().map_err(|e| e.to_string())?;
    ch1.exec("bash -lc 'openclaw sessions --all-agents --json'").map_err(|e| e.to_string())?;
    let mut out1 = String::new();
    let _ = ch1.read_to_string(&mut out1);
    let _ = ch1.wait_close();

    // 2. 获取 status 活跃频道
    let mut ch2 = sess.channel_session().map_err(|e| e.to_string())?;
    ch2.exec("bash -lc 'openclaw status --json'").map_err(|e| e.to_string())?;
    let mut out2 = String::new();
    let _ = ch2.read_to_string(&mut out2);
    let _ = ch2.wait_close();

    // 过滤可能存在于 JSON 之前的 stderr 噪音，从第一个 '{' 开始解析
    let json1_str = out1.find('{').map(|i| &out1[i..]).unwrap_or("{}");
    let v1: serde_json::Value = serde_json::from_str(json1_str).unwrap_or_else(|_| serde_json::json!({}));

    let json2_str = out2.find('{').map(|i| &out2[i..]).unwrap_or("{}");
    let v2: serde_json::Value = serde_json::from_str(json2_str).unwrap_or_else(|_| serde_json::json!({}));

    // 过滤今日数据：获取近 24 小时的毫秒时间戳
    let now_ms = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64;
    let day_ms = 24 * 3600 * 1000;
    let threshold = if now_ms > day_ms { now_ms - day_ms } else { 0 };

    // 汇总今日 Token
    let mut token_sum: u64 = 0;
    if let Some(sessions) = v1["sessions"].as_array() {
        for s in sessions {
            let updated_at = s["updatedAt"].as_u64().unwrap_or(0);
            if updated_at >= threshold {
                token_sum += s["totalTokens"].as_u64().unwrap_or(0);
            }
        }
    }

    // 解析请求总量 (总 session 数量)
    let total_req = v1["count"].as_u64().unwrap_or(0) as u32;

    // 解析活跃连接数 (channelSummary 长度)
    let active_links = v2["channelSummary"].as_array().map(|a| a.len()).unwrap_or(0) as u32;

    // 格式化 Token 显示逻辑 (K / M)
    let token_str = if token_sum < 1000 {
        token_sum.to_string()
    } else if token_sum < 1_000_000 {
        format!("{:.1}K", token_sum as f64 / 1000.0)
    } else {
        format!("{:.1}M", token_sum as f64 / 1_000_000.0)
    };

    Ok((token_str, active_links, total_req))
}

#[command]
fn check_connection(ip: String) -> bool {
    match format!("{}:22", ip).to_socket_addrs() {
        Ok(mut addrs) => {
            if let Some(addr) = addrs.next() {
                return TcpStream::connect_timeout(&addr, Duration::from_secs(3)).is_ok();
            }
            false
        }
        Err(_) => false,
    }
}

#[command]
fn clear_ssh_cache() -> Result<String, String> {
    if let Ok(home) = std::env::var("USERPROFILE") {
        let known_hosts = std::path::Path::new(&home).join(".ssh").join("known_hosts");
        if known_hosts.exists() {
            match std::fs::remove_file(known_hosts) {
                Ok(_) => return Ok("SSH 缓存已清理".to_string()),
                Err(e) => return Err(format!("清理失败: {}", e)),
            }
        }
    }
    Ok("无 SSH 残留缓存".to_string())
}

#[command]
fn kill_port_process(port: u16) -> Result<String, String> {
    let output = Command::new("cmd")
        .args(["/C", &format!("for /f \"tokens=5\" %a in ('netstat -aon ^| findstr :{}') do taskkill /f /pid %a", port)])
        .output()
        .map_err(|e| e.to_string())?;

    if output.status.success() { Ok(format!("强制释放成功")) } 
    else { Err("未找到占用进程".to_string()) }
}

fn spawn_tunnel(
    listener: TcpListener, ip: String, user: String, pass: String, remote_port: u16, is_running: Arc<AtomicBool>
) {
    listener.set_nonblocking(true).unwrap_or(());
    thread::spawn(move || {
        loop {
            if !is_running.load(Ordering::Relaxed) { break; }
            match listener.accept() {
                Ok((mut local_stream, _)) => {
                    let (it, ut, pt) = (ip.clone(), user.clone(), pass.clone());
                    let is_running_inner = is_running.clone();
                    thread::spawn(move || {
                        if let Ok(t) = TcpStream::connect(format!("{}:22", it)) {
                            if let Ok(mut s) = Session::new() {
                                s.set_tcp_stream(t);
                                if s.handshake().is_ok() && s.userauth_password(&ut, &pt).is_ok() {
                                    if let Ok(mut c) = s.channel_direct_tcpip("127.0.0.1", remote_port, None) {
                                        local_stream.set_nonblocking(true).unwrap_or(());
                                        s.set_blocking(false);
                                        let (mut b1, mut b2) = ([0; 8192], [0; 8192]);
                                        loop {
                                            if !is_running_inner.load(Ordering::Relaxed) { break; }
                                            let mut act = false;
                                            if let Ok(n) = local_stream.read(&mut b1) {
                                                if n == 0 { break; }
                                                let _ = c.write_all(&b1[..n]);
                                                act = true;
                                            }
                                            match c.read(&mut b2) {
                                                Ok(n) if n > 0 => { let _ = local_stream.write_all(&b2[..n]); act = true; }
                                                Ok(_) => break,
                                                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {},
                                                Err(_) => break,
                                            }
                                            if !act { thread::sleep(Duration::from_millis(5)); }
                                        }
                                    }
                                }
                            }
                        }
                    });
                }
                Err(_) => { thread::sleep(Duration::from_millis(50)); }
            }
        }
    });
}

#[command]
async fn connect_ssh(
    app: AppHandle, ip: String, user: String, pass: String, webui_port: u16, extra_forward: String
) -> Result<String, String> {
    let _ = app.emit("tunnel-status", format!("正在握手并分配端口..."));

    let tcp = TcpStream::connect(format!("{}:22", &ip)).map_err(|e| format!("连接失败: {}", e))?;
    let mut sess = Session::new().map_err(|e| e.to_string())?;
    sess.set_tcp_stream(tcp);
    sess.set_timeout(10000);
    sess.handshake().map_err(|e| e.to_string())?;
    sess.userauth_password(&user, &pass).map_err(|_| "认证失败".to_string())?;

    let mut actual_webui_port = webui_port;
    let listener_webui = loop {
        match TcpListener::bind(format!("127.0.0.1:{}", actual_webui_port)) {
            Ok(l) => break l,
            Err(_) => {
                actual_webui_port += 1;
                if actual_webui_port > webui_port + 50 { return Err(format!("本地端口已耗尽")); }
            }
        }
    };

    let is_running = Arc::new(AtomicBool::new(true));
    get_tunnels().lock().unwrap().insert(actual_webui_port, is_running.clone());

    spawn_tunnel(listener_webui, ip.clone(), user.clone(), pass.clone(), 18789, is_running.clone());

    if !extra_forward.trim().is_empty() {
        let parts: Vec<&str> = extra_forward.split(':').collect();
        let (e_local, e_remote) = if parts.len() == 2 {
            (parts[0].parse::<u16>().unwrap_or(0), parts[1].parse::<u16>().unwrap_or(0))
        } else if parts.len() == 1 {
            let p = parts[0].parse::<u16>().unwrap_or(0);
            (p, p)
        } else { (0, 0) };

        if e_local > 0 && e_remote > 0 {
            if let Ok(listener_extra) = TcpListener::bind(format!("127.0.0.1:{}", e_local)) {
                spawn_tunnel(listener_extra, ip.clone(), user.clone(), pass.clone(), e_remote, is_running.clone());
            } else {
                let _ = app.emit("tunnel-status", format!("⚠️ 附加端口 {} 冲突", e_local));
            }
        }
    }

    Ok(actual_webui_port.to_string())
}

#[command]
fn close_tunnel(local_port: u16) -> Result<String, String> {
    if let Some(flag) = get_tunnels().lock().unwrap().remove(&local_port) {
        flag.store(false, Ordering::Relaxed);
        Ok(format!("释放成功"))
    } else { Err("无实例".to_string()) }
}

#[command]
async fn fetch_token(ip: String, user: String, pass: String) -> Result<String, String> {
    let tcp = TcpStream::connect(format!("{}:22", &ip)).map_err(|e| e.to_string())?;
    let mut sess = Session::new().map_err(|e| e.to_string())?;
    sess.set_tcp_stream(tcp);
    sess.handshake().map_err(|e| e.to_string())?;
    sess.userauth_password(&user, &pass).map_err(|e| e.to_string())?;
    let mut channel = sess.channel_session().map_err(|e| e.to_string())?;
    channel.exec("bash -lc 'openclaw dashboard'").map_err(|e| e.to_string())?;
    let mut out = String::new(); 
    let mut buf = [0; 2048];
    let re = Regex::new(r"token=([a-fA-F0-9]{32,})").unwrap();
    for _ in 0..40 {
        if let Ok(n) = channel.read(&mut buf) {
            if n > 0 {
                let chunk = String::from_utf8_lossy(&buf[..n]);
                out.push_str(&chunk);
                if let Some(caps) = re.captures(&out) { return Ok(caps[1].to_string()); }
            }
        }
        thread::sleep(Duration::from_millis(300));
    }
    Err("未能截获 Token".to_string())
}

#[command]
fn open_dashboard(token: String, port: u16) {
    let url = format!("http://127.0.0.1:{}/#token={}", port, token);
    let _ = std::process::Command::new("cmd").args(["/C", "start", "", &url]).spawn();
}

#[command]
fn disconnect_ssh() {
    let mut tunnels = get_tunnels().lock().unwrap();
    for flag in tunnels.values() { flag.store(false, Ordering::Relaxed); }
    tunnels.clear();
    std::process::exit(0);
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            connect_ssh, close_tunnel, disconnect_ssh, fetch_token, open_dashboard, 
            clear_ssh_cache, kill_port_process, get_dynamic_metrics, check_connection
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}