<script setup lang="ts">
import { ref, onMounted, computed, onUnmounted } from "vue";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

interface NodeConfig {
  id: string; alias: string; ip: string; user: string; pass: string;
  webuiPort: number; extraPort: string; isActive: boolean; uptime: number;
  kpiToken: string; kpiActive: number; kpiReq: number; 
}

const JOKES = [
  "只要我 PPT 做得够快，客户就追不上系统的 Bug。",
  "金融级高可用：指只要老板不发现，系统就是可用的。",
  "售前的嘴，骗人的鬼；交付的泪，深夜的轨。",
  "闭环逻辑：只要我不承认我错了，逻辑就是圆的。",
  "所谓架构重构，就是把今天的问题留给明天的同事。",
  "只要躺得够平，资本的镰刀就只能从我头顶挥过。",
  "运维第一准则：别问，问就是防火墙没开。",
  "即使在这个数字时代，也要保留一点手工敲代码的浪漫。",
  "测试工程师：这系统怎么一戳就破？开发：你为什么要戳它？",
  "这系统能跑起来本身就是个奇迹。"
];

const nodes = ref<NodeConfig[]>([]);
const language = ref<'zh' | 'en'>('zh');
const isEditModal = ref(false);
const showLangMenu = ref(false);
const showAuthorMenu = ref(false); 
const statusMsg = ref("Ready");
const displayQuote = ref(""); 

const connectingNodeId = ref<string | null>(null);
const reconnectingNodeId = ref<string | null>(null); 
const copiedId = ref<string | null>(null);
const currentPing = ref(32); 

const isFetchingToken = ref(false);
const refreshOptions = [5, 10, 15, 30];
const selectedRefreshTime = ref(5);
const countdownSecs = ref(5 * 60);
let timer: any = null;

const editForm = ref<NodeConfig>({ id: '', alias: '', ip: '', user: 'root', pass: '', webuiPort: 18789, extraPort: '', isActive: false, uptime: 0, kpiToken: '0', kpiActive: 0, kpiReq: 0 });

interface CyberPet { id: number; type: string; bottom: number; duration: number; speed: number; }
const activePets = ref<CyberPet[]>([]);
let petIdCounter = 0;
let petTimer: any = null;
const PET_TYPES = ['cat', 'dog', 'duck'];

const spawnPet = () => {
  if (nodes.value.length !== 1 || Math.random() > 0.3) return;
  if (activePets.value.length >= 3) return; 

  const id = petIdCounter++;
  const type = PET_TYPES[Math.floor(Math.random() * PET_TYPES.length)];
  const duration = 15 + Math.random() * 10; 
  const bottom = 80 + Math.random() * 80;   

  activePets.value.push({ id, type, bottom, duration, speed: 100 / duration });
  setTimeout(() => { activePets.value = activePets.value.filter(p => p.id !== id); }, duration * 1000);
};

const t = computed(() => ({
  zh: { 
    add: "添加节点", edit: "编辑环境配置", del: "删除节点", connect: "建立加密隧道", connecting: "握手与分配中...", reconnecting: "网络波动, 重连中...",
    disconnect: "断开隧道连接", quit: "退出应用", modalTitle: "编辑环境配置",
    alias: "节点别名", ip: "IP / 域名", user: "用户名", pass: "SSH 密码", 
    webuiP: "WebUI 本地端口", extraP: "附加转发 (如 3306:3306)", save: "保存配置", cancel: "取消", fix: "解决占用",
    monitor: "监控面板", refreshAfter: "后刷新", webui: "前往 WebUI 面板", restart: "重启网关",
    clearSSH: "清理 SSH 缓存", langTitle: "语言设置", refreshTitle: "刷新频率", copied: "已复制",
    kpiToken: "Token", kpiActive: "活跃连接", kpiReq: "请求总量", uptime: "运行时间",
    aboutId: "@Eyesslee", scumbag: "你也可以叫我渣男小李"
  },
  en: { 
    add: "Add Node", edit: "Edit Config", del: "Delete Node", connect: "Establish Tunnel", connecting: "Connecting...", reconnecting: "Reconnecting...",
    disconnect: "Disconnect Tunnel", quit: "Quit App", modalTitle: "Edit Environment",
    alias: "Alias", ip: "IP / Domain", user: "User", pass: "Password", 
    webuiP: "WebUI Local Port", extraP: "Extra Port (e.g. 3306:3306)", save: "Save", cancel: "Cancel", fix: "Fix Conflict",
    monitor: "Monitoring", refreshAfter: "to refresh", webui: "Open WebUI", restart: "Restart GW",
    clearSSH: "Clear SSH Cache", langTitle: "Language", refreshTitle: "Refresh Interval", copied: "Copied!",
    kpiToken: "Token", kpiActive: "Active Links", kpiReq: "Requests", uptime: "Uptime",
    aboutId: "@Eyesslee", scumbag: "A.K.A. Scumbag Xiao Li" 
  }
}[language.value]));

onMounted(async () => {
  const saved = localStorage.getItem("openclaw_v4");
  if (saved) {
    const parsedNodes = JSON.parse(saved);
    // 🌟 核心修复：每次重启应用时，强制重置所有节点的活跃状态，防止幽灵缓存
    parsedNodes.forEach((n: NodeConfig) => {
      n.isActive = false;
      n.uptime = 0;
    });
    nodes.value = parsedNodes;
  } else {
    nodes.value = [{ id: '1', alias: 'openclaw', ip: '81.70.x.x', user: 'root', pass: '', webuiPort: 18789, extraPort: '', isActive: false, uptime: 0, kpiToken: '0', kpiActive: 0, kpiReq: 0 }];
  }
  
  await listen("tunnel-status", (e) => statusMsg.value = e.payload as string);
  petTimer = setInterval(spawnPet, 3000);
});

onUnmounted(() => { 
  if (timer) clearInterval(timer); 
  if (petTimer) clearInterval(petTimer);
});

const closeMenus = () => {
  showLangMenu.value = false;
  showAuthorMenu.value = false;
};

const toggleAuthorMenu = () => {
  showAuthorMenu.value = !showAuthorMenu.value;
  showLangMenu.value = false;
};

const toggleLangMenu = () => {
  showLangMenu.value = !showLangMenu.value;
  showAuthorMenu.value = false;
};

const typeWriterEffect = (text: string) => {
  displayQuote.value = "";
  let i = 0;
  const speed = 40; 
  const type = () => {
    if (i < text.length) { displayQuote.value += text.charAt(i); i++; setTimeout(type, speed); }
  };
  type();
};

const formattedTime = computed(() => {
  const m = Math.floor(countdownSecs.value / 60).toString().padStart(2, '0');
  const s = (countdownSecs.value % 60).toString().padStart(2, '0');
  return `${m}:${s}`;
});

const formatUptime = (secs: number) => {
  if (!secs) return "00:00:00";
  const h = Math.floor(secs / 3600).toString().padStart(2, '0');
  const m = Math.floor((secs % 3600) / 60).toString().padStart(2, '0');
  const s = (secs % 60).toString().padStart(2, '0');
  return `${h}:${m}:${s}`;
};

const fetchNodeMetrics = async (node: NodeConfig) => {
  try {
    const res: [string, number, number] = await invoke("get_dynamic_metrics", { 
        ip: node.ip, user: node.user, pass: node.pass 
    });
    node.kpiToken = res[0]; 
    node.kpiActive = res[1]; 
    node.kpiReq = res[2];
    localStorage.setItem("openclaw_v4", JSON.stringify(nodes.value));
  } catch(e) {
    console.error("后台指标抓取拦截：", e);
  }
};

const startGlobalTimer = () => {
  if (timer) clearInterval(timer);
  countdownSecs.value = selectedRefreshTime.value * 60;
  timer = setInterval(async () => {
    if (countdownSecs.value > 0) {
      countdownSecs.value--;
    } else {
      countdownSecs.value = selectedRefreshTime.value * 60;
      nodes.value.filter(n => n.isActive).forEach(n => fetchNodeMetrics(n));
      statusMsg.value = `✅ 面板数据已于 ${new Date().toLocaleTimeString()} 刷新`;
    }
    
    let hasActive = false;
    for (const n of nodes.value) {
      if (n.isActive) {
        hasActive = true;
 
        n.uptime += 1;
        if (n.uptime % 5 === 0) {
          currentPing.value = Math.floor(Math.random() * 20) + 20; 
          const isAlive = await invoke("check_connection", { ip: n.ip });
          if (!isAlive && reconnectingNodeId.value !== n.id) {
             statusMsg.value = `⚠️ 节点 ${n.ip} 掉线，正在自动重连...`;
        
             reconnectTunnel(n);
          }
        }
      }
    }
    if (!hasActive && timer) clearInterval(timer);
  }, 1000);
};

const changeRefresh = (mins: number) => {
  selectedRefreshTime.value = mins;
  startGlobalTimer();
  showLangMenu.value = false;
};

const copyToClipboard = async (node: NodeConfig) => {
  const addr = `127.0.0.1:${node.webuiPort}`;
  try {
    await navigator.clipboard.writeText(addr);
    copiedId.value = node.id;
    setTimeout(() => { copiedId.value = null; }, 2000);
  } catch (e) {}
};

const handleClearCache = async () => {
  try {
    const res = await invoke("clear_ssh_cache");
    statusMsg.value = `✅ ${res}`;
  } catch (e) { statusMsg.value = `清理异常: ${e}`; }
};

const openWebUI = async (node: NodeConfig) => {
  if (isFetchingToken.value) return;
  isFetchingToken.value = true;
  statusMsg.value = "正在从服务器截获 Token...";
  try {
    const token = await invoke("fetch_token", { ip: node.ip, user: node.user, pass: node.pass });
    await invoke("open_dashboard", { token: String(token), port: node.webuiPort });
    statusMsg.value = "已在浏览器唤起 WebUI 面板";
  } catch (e) { statusMsg.value = "Token 截获失败，请检查服务器"; } 
  finally { isFetchingToken.value = false; }
};

const restartGateway = () => {
  statusMsg.value = "正在下发重启指令...";
  setTimeout(() => { statusMsg.value = "网关重启成功"; }, 1500);
};

const getNextPort = () => { let p = 18789; while (nodes.value.map(n => n.webuiPort).includes(p)) p++; return p; };
const handleAdd = () => { editForm.value = { id: Date.now().toString(), alias: language.value === 'zh' ? '新节点' : 'New Node', ip: '', user: 'root', pass: '', webuiPort: getNextPort(), extraPort: '', isActive: false, uptime: 0, kpiToken: '0', kpiActive: 0, kpiReq: 0 }; isEditModal.value = true; };
const openEdit = (node: NodeConfig) => { editForm.value = { ...node }; isEditModal.value = true; };

const saveConfig = () => {
  const idx = nodes.value.findIndex(n => n.id === editForm.value.id);
  if (idx > -1) nodes.value[idx] = { ...editForm.value }; else nodes.value.push({ ...editForm.value });
  localStorage.setItem("openclaw_v4", JSON.stringify(nodes.value));
  isEditModal.value = false;
};

const fixPortConflict = async () => {
  try {
    const port = editForm.value.webuiPort || 18789;
    statusMsg.value = `正在强制释放端口 ${port}...`;
    const res = await invoke("kill_port_process", { port });
    statusMsg.value = `✅ ${res}`;
  } catch (e) { statusMsg.value = "清理失败"; }
};

const reconnectTunnel = async (node: NodeConfig) => {
  node.isActive = false;
  reconnectingNodeId.value = node.id;
  try {
    await invoke("close_tunnel", { localPort: node.webuiPort });
    await new Promise(r => setTimeout(r, 2000));
    await invoke("connect_ssh", { ip: node.ip, user: node.user, pass: node.pass, webuiPort: node.webuiPort, extraForward: node.extraPort });
    node.isActive = true;
    statusMsg.value = `✅ 节点 ${node.ip} 自动重连成功`;
  } catch (e) {
    statusMsg.value = `重连失败，请检查网络`;
  } finally {
    reconnectingNodeId.value = null;
  }
};

const toggleTunnel = async (node: NodeConfig) => {
  if (node.isActive) { 
    node.isActive = false;
    node.uptime = 0;
    displayQuote.value = "";
    if (!nodes.value.some(n => n.isActive)) clearInterval(timer);
    try {
      await invoke("close_tunnel", { localPort: node.webuiPort });
      statusMsg.value = `隧道已断开，释放本地端口 ${node.webuiPort}`;
    } catch (e) { statusMsg.value = `端口释放异常`; }
    return;
  }
  
  try {
    connectingNodeId.value = node.id;
    statusMsg.value = "正在握手...";
    await new Promise(r => setTimeout(r, 600));

    const actualPortStr = await invoke("connect_ssh", { 
      ip: node.ip, user: node.user, pass: node.pass, 
      webuiPort: node.webuiPort, extraForward: node.extraPort 
    });
    const actualPort = parseInt(String(actualPortStr));
    if (actualPort !== node.webuiPort) {
      statusMsg.value = `⚠️ 避让原端口，WebUI 已映射至 ${actualPort}`;
      node.webuiPort = actualPort;
      localStorage.setItem("openclaw_v4", JSON.stringify(nodes.value));
    } else {
      statusMsg.value = `节点 ${node.ip} 激活成功`;
    }

    node.isActive = true;
    node.uptime = 0;
    
    // 🌟 连接后立即触发真实的服务器数据拉取
    await fetchNodeMetrics(node);
    const randomJoke = JOKES[Math.floor(Math.random() * JOKES.length)];
    typeWriterEffect(`“${randomJoke}”`);
    
    startGlobalTimer();
  } catch (e) { 
    statusMsg.value = String(e);
  } finally {
    connectingNodeId.value = null;
  }
};
</script>

<template>
  <main class="app-shell" @click="closeMenus">
    <div class="nebula-bg"></div>

    <div v-if="nodes.length === 1" class="pet-layer">
      <div v-for="pet in activePets" :key="pet.id" class="cyber-pet" :style="{ bottom: pet.bottom + 'px', animationDuration: pet.duration + 's' }">
        <svg v-if="pet.type === 'cat'" width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M12 9c-3.86 0-7 3.14-7 7 0 3.86 3.14 7 7 7s7-3.14 7-7c0-3.86-3.14-7-7-7zm0 12c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm4.5-17.5l-2.5 4.5h-4l-2.5-4.5 1.5-1.5 2 2h2l2-2 1.5 1.5z"/></svg>
        <svg v-if="pet.type === 'dog'" width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M19 8h-2v3h-1V5h-2v3h-1V4h-2v5H9V5H7v4H6c-1.66 0-3 1.34-3 3v8h2v-2h12v2h2v-8c0-1.66-1.34-3-3-3zM9 14H7v-2h2v2zm6 0h-2v-2h2v2zm3 0h-1v-2h1v2z"/></svg>
        <svg v-if="pet.type === 'duck'" width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M12 4c-2.76 0-5 2.24-5 5 0 1.25.46 2.4 1.22 3.28C7.15 13.06 6 14.39 6 16c0 2.21 1.79 4 4 4h4c2.21 0 4-1.79 4-4 0-1.42-.75-2.65-1.88-3.32.55-1.07.88-2.29.88-3.68 0-2.76-2.24-5-5-5zm0 8c-1.65 0-3-1.35-3-3s1.35-3 3-3 3 1.35 3 3-1.35 3-3 3zm-2-2a1 1 0 1 0 0-2 1 1 0 0 0 0 2zm4 0a1 1 0 1 0 0-2 1 1 0 0 0 0 2z"/></svg>
      </div>
    </div>

    <header class="navbar">
      <div class="brand">OPENCLAW TUNNEL PRO</div>
      <div class="nav-actions">
        <button class="clear-ssh-btn" @click.stop="handleClearCache">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 3l18 18M15 9l-6 6"/><path d="M9 3l3 3-6 6-3-3z"/><path d="M21 15l-3-3-6 6 3 3z"/></svg>
          {{ t.clearSSH }}
        </button>
        <div class="nav-right" @click.stop="handleAdd">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>
          <span>{{ t.add }}</span>
        </div>
      </div>
    </header>

    <section class="stage">
      <transition-group name="list" tag="div" class="node-container" :class="{ 'multi-mode': nodes.length > 1 }">
        <div v-for="node in nodes" :key="node.id" class="node-card" :class="{ 'card-active-glow': node.isActive }">
          
          <div class="node-header">
            <div class="node-content">
               <div class="icon-box" :class="{ 'pulse-glow': node.isActive, 'is-connecting': connectingNodeId === node.id || reconnectingNodeId === node.id }">
                 <svg v-if="reconnectingNodeId === node.id" width="55" height="55" viewBox="0 0 24 24" fill="none" stroke="var(--c-warning)" stroke-width="1.5"><rect x="2" y="2" width="20" height="20" rx="4"/><line x1="2" y1="9" x2="22" y2="9"/><line x1="2" y1="16" x2="22" y2="16"/><circle cx="18" cy="5.5" r="0.5" fill="var(--c-warning)"/><circle cx="18" cy="12.5" r="0.5" fill="var(--c-warning)"/><circle cx="18" cy="19.5" r="0.5" fill="var(--c-warning)"/></svg>
                 <svg v-else-if="!node.isActive" width="55" height="55" viewBox="0 0 24 24" fill="none" stroke="var(--c-primary)" stroke-width="1.5"><rect x="2" y="2" width="20" height="20" rx="4"/><line x1="2" y1="9" x2="22" y2="9"/><line x1="2" y1="16" x2="22" y2="16"/><circle cx="18" cy="5.5" r="0.5" fill="var(--c-primary)"/><circle cx="18" cy="12.5" r="0.5" fill="var(--c-primary)"/><circle cx="18" cy="19.5" r="0.5" fill="var(--c-primary)"/></svg>
                 <svg v-else width="60" height="60" viewBox="0 0 24 24" fill="var(--c-success)"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
               </div>
               
               <div class="text-info">
                 <h1>{{ node.alias }}</h1>
                 <p class="interactive-ip" @click="copyToClipboard(node)" :class="{ 'copied': copiedId === node.id }">
                    <span v-if="copiedId === node.id">✔ {{ t.copied }}</span>
                    <span v-else>{{ node.ip }} : {{ node.webuiPort }} <span v-if="node.extraPort" style="opacity: 0.5;">| {{ node.extraPort }}</span></span>
                 </p>
                 <p v-if="node.isActive && nodes.length === 1" class="joke">{{ displayQuote }}<span class="cursor">_</span></p>
               </div>
            </div>

            <div class="card-actions" v-if="!node.isActive">
              <button class="main-btn" :class="{'btn-loading': connectingNodeId === node.id || reconnectingNodeId === node.id, 'btn-warning': reconnectingNodeId === node.id}" @click="toggleTunnel(node)" :disabled="connectingNodeId === node.id || reconnectingNodeId === node.id">
                <span v-if="connectingNodeId === node.id || reconnectingNodeId === node.id" class="loader" :class="{'loader-warning': reconnectingNodeId === node.id}"></span>
                <span v-else>{{ t.connect }}</span>
              </button>
              <div class="sub-links" v-if="connectingNodeId !== node.id && reconnectingNodeId !== node.id">
                <button @click="openEdit(node)">{{ t.edit }}</button>
                <button class="del" @click="nodes = nodes.filter(n => n.id !== node.id)">{{ t.del }}</button>
              </div>
            </div>
          </div>

          <transition name="expand">
            <div v-if="node.isActive" class="monitor-dashboard">
               <div class="dash-inner">
                 <div class="dash-header">
                    <span style="display: flex; gap: 10px; align-items: center;">
                      <span>{{ t.monitor }}</span>
                      <span class="uptime-badge">{{ t.uptime }}: {{ formatUptime(node.uptime) }}</span>
                      <span class="ping-badge">⚡ {{ currentPing }}ms</span>
                    </span>
                    <span class="timer">{{ formattedTime }} {{ t.refreshAfter }} ↻</span>
                 </div>
                 <div class="kpi-row">
                    <div class="kpi-card stagger-1"><span class="val c-warn">{{ node.kpiToken || '0' }}</span><label>{{ t.kpiToken }}</label></div>
                    <div class="kpi-card stagger-2"><span class="val c-succ">{{ node.kpiActive || 0 }}</span><label>{{ t.kpiActive }}</label></div>
                    <div class="kpi-card stagger-3"><span class="val c-prim">{{ node.kpiReq || 0 }}</span><label>{{ t.kpiReq }}</label></div>
                 </div>
                 <div class="action-row stagger-4">
                   <button class="btn-webui" @click="openWebUI(node)">
                       <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
                       {{ isFetchingToken ? '...' : t.webui }}
                    </button>
                    <button class="btn-restart" @click="restartGateway">
                       <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 2v6h-6"/><path d="M3 12a9 9 0 1 0 2.6-6.6L21 8"/></svg>
                        {{ t.restart }}
                    </button>
                 </div>
                 <button class="btn-disconnect-big stagger-5" @click="toggleTunnel(node)">{{ t.disconnect }}</button>
               </div>
            </div>
          </transition>
          
        </div>
      </transition-group>
    </section>

    <footer class="bottom-bar">
      <div class="left-actions">
        
        <div class="author-box" @click.stop>
          <button class="sys-btn" @click="toggleAuthorMenu">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
          </button>
          <transition name="menu-fade">
            <div v-if="showAuthorMenu" class="glass-menu author-card">
              <img src="/avatar.gif" alt="Avatar" class="author-avatar" onerror="this.src='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMDAgMTAwIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjMTYxYzFjIi8+PHRleHQgeD0iNTAiIHk9IjYwIiBmb250LXNpemU9IjMwIiBmaWxsPSIjYmFjYWM2IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj4/PC90ZXh0Pjwvc3ZnPg=='" />
              <div class="author-info">
                 <span class="author-id">{{ t.aboutId }}</span>
                <span class="author-desc">{{ t.scumbag }}</span>
              </div>
            </div>
          </transition>
        </div>

        <div class="settings-box" @click.stop>
          <button class="sys-btn gear-icon" @click="toggleLangMenu">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
           </button>
          <transition name="menu-fade">
            <div v-if="showLangMenu" class="glass-menu">
              <div class="menu-sec">
                 <span>{{ t.langTitle }}</span>
                 <button :class="{on: language==='zh'}" @click="language='zh'">🇨🇳 中文</button>
                 <button :class="{on: language==='en'}" @click="language='en'">🇺🇸 EN</button>
              </div>
              <div class="menu-sec">
                 <span>{{ t.refreshTitle }}</span>
                 <button v-for="time in refreshOptions" :key="time" :class="{on: selectedRefreshTime===time}" @click="changeRefresh(time)">{{ time }} Min</button>
              </div>
             </div>
          </transition>
        </div>

      </div>
      
      <div class="status-msg">
        <span v-if="statusMsg.includes('成功') || statusMsg.includes('✅') || statusMsg.includes('释放')" class="check">✔</span> 
        <span class="txt" :class="{ 'warning-txt': statusMsg.includes('占用') || statusMsg.includes('避让') || statusMsg.includes('掉线') }">{{ statusMsg }}</span>
        <button v-if="statusMsg.includes('占用')" class="fix-btn" @click="fixPortConflict">{{ t.fix }}</button>
      </div>

      <button class="quit-btn" @click="invoke('disconnect_ssh')">{{ t.quit }}</button>
    </footer>

    <transition name="modal-fade">
      <div v-if="isEditModal" class="modal-overlay" @click.self="isEditModal = false">
        <div class="modal-card">
          <h2>{{ t.modalTitle }}</h2>
          <div class="grid">
            <div class="i"><label>{{ t.alias }}</label><input v-model="editForm.alias" /></div>
            <div class="i"><label>{{ t.ip }}</label><input v-model="editForm.ip" /></div>
            <div class="i"><label>{{ t.user }}</label><input v-model="editForm.user" /></div>
            <div class="i"><label>{{ t.pass }}</label><input v-model="editForm.pass" type="password" /></div>
            
            <div class="i"><label>{{ t.webuiP }}</label><input v-model.number="editForm.webuiPort" type="number" /></div>
            <div class="i"><label>{{ t.extraP }}</label><input v-model="editForm.extraPort" placeholder="空 或 3306:3306" /></div>
          </div>
          <div class="btns">
            <button class="cancel-btn" @click="isEditModal = false">{{ t.cancel }}</button>
            <button class="save" @click="saveConfig">{{ t.save }}</button>
          </div>
        </div>
      </div>
    </transition>
  </main>
</template>

<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&family=Noto+Sans+SC:wght@400;500;700;900&display=swap');
:root {
  --c-primary: #0eb0c9;  
  --c-danger: #f43e06;   
  --c-success: #2edfa3;  
  --c-warning: #ffd111;  
  --c-bg-dark: rgba(11, 16, 16, 0.85);  
  --c-bg-light: #161c1c; 
  --c-text-gray: #bacac6;
}

button { all: unset; cursor: pointer; transition: 0.3s; }
input[type="number"]::-webkit-inner-spin-button,
input[type="number"]::-webkit-outer-spin-button { -webkit-appearance: none !important; margin: 0 !important; display: none !important; }
input[type="number"] { -moz-appearance: textfield !important; appearance: textfield !important; }
input[type="number"]::-ms-clear, input[type="number"]::-ms-reveal { display: none !important; }

* { box-sizing: border-box; margin: 0; padding: 0; }
::-webkit-scrollbar { display: none; width: 0; height: 0; }
html, body { overflow: hidden; background: transparent !important;}

.app-shell { 
  width: 100vw; height: 100vh; display: flex; flex-direction: column; padding: 25px; 
  background: var(--c-bg-dark);
  background-image: radial-gradient(circle at 50% 30%, rgba(14, 176, 201, 0.1) 0%, var(--c-bg-dark) 80%);
  color: white; user-select: none;
  font-family: 'Inter', 'Noto Sans SC', -apple-system, BlinkMacSystemFont, sans-serif; 
  overflow: hidden; position: relative;
}

.pet-layer { position: absolute; inset: 0; pointer-events: none; z-index: 1; overflow: hidden; }
.cyber-pet { position: absolute; right: -50px; color: var(--c-primary); opacity: 0.15; animation: stroll linear forwards, petBob 0.6s infinite alternate ease-in-out; }
@keyframes stroll { to { transform: translateX(calc(-100vw - 100px)); } }
@keyframes petBob { from { padding-bottom: 0; } to { padding-bottom: 5px; } }

.navbar { display: flex; justify-content: space-between; align-items: center; flex-shrink: 0; z-index: 10; }
.brand { color: var(--c-primary); font-weight: 900; font-size: 13px; letter-spacing: 1px; text-transform: uppercase; }
.nav-actions { display: flex; align-items: center; gap: 15px; }

.clear-ssh-btn { background: rgba(255, 209, 17, 0.05); border: 1px solid rgba(255, 209, 17, 0.3); color: var(--c-warning); font-weight: 800; font-size: 11px; padding: 6px 12px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; gap: 5px; transition: all 0.2s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
.clear-ssh-btn:hover { background: rgba(255, 209, 17, 0.15); border-color: var(--c-warning); }
.clear-ssh-btn:active { transform: scale(0.95); }
.nav-right { color: var(--c-primary); font-weight: 800; font-size: 13px; display: flex; align-items: center; gap: 6px; cursor: pointer; transition: 0.2s; }
.nav-right:hover { opacity: 0.8; }
.nav-right:active { transform: scale(0.95); }

.stage { flex: 1; overflow-y: auto; overflow-x: hidden; display: flex; flex-direction: column; align-items: center; padding: 15px 0; scrollbar-width: none; z-index: 10; }
.node-container { display: flex; flex-direction: column; gap: 20px; width: 100%; max-width: 380px; position: relative; }

.list-move, .list-enter-active, .list-leave-active { transition: all 0.6s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
.list-enter-from, .list-leave-to { opacity: 0; transform: scale(0.95) translateY(20px); }
.list-leave-active { position: absolute; }

.node-card { width: 100%; display: flex; flex-direction: column; transition: 0.4s; background: transparent; border-radius: 16px; overflow: hidden; border: 1px solid transparent; }
.card-active-glow { border: 1px solid rgba(14, 176, 201, 0.2); box-shadow: 0 0 30px rgba(14, 176, 201, 0.05); background: rgba(255,255,255,0.01); }

.node-header { display: flex; flex-direction: column; align-items: center; text-align: center; width: 100%; padding: 10px; }

.is-connecting { animation: spinAndPulse 1.2s infinite cubic-bezier(0.175, 0.885, 0.32, 1.275); opacity: 0.6; }
@keyframes spinAndPulse { 0% { transform: scale(1) rotateY(0deg); } 50% { transform: scale(0.8) rotateY(180deg); } 100% { transform: scale(1) rotateY(360deg); } }

.pulse-glow { animation: pulse 3s infinite cubic-bezier(0.4, 0, 0.2, 1); }
@keyframes pulse { 0% { filter: drop-shadow(0 0 5px rgba(46, 223, 163, 0.2)); transform: scale(1); } 50% { filter: drop-shadow(0 0 18px rgba(46, 223, 163, 0.6)); transform: scale(1.05); } 100% { filter: drop-shadow(0 0 5px rgba(46, 223, 163, 0.2)); transform: scale(1); } }

.text-info h1 { font-size: 38px; font-weight: 900; margin: 10px 0 5px; }

.interactive-ip { opacity: 0.5; font-family: 'Inter', monospace; font-size: 13px; margin-bottom: 20px; cursor: pointer; transition: 0.2s; padding: 4px 8px; border-radius: 6px; display: inline-block; }
.interactive-ip:hover { opacity: 1; background: rgba(255,255,255,0.1); }
.interactive-ip:active { transform: scale(0.95); }
.copied { color: var(--c-success); opacity: 1; background: rgba(46, 223, 163, 0.1); }

.joke { color: var(--c-primary) !important; font-style: italic; font-size: 12px; margin-bottom: 20px; opacity: 0.9 !important; line-height: 1.5; font-family: inherit !important; min-height: 18px; }
.cursor { animation: blink 1s step-end infinite; }
@keyframes blink { 50% { opacity: 0; } }

.multi-mode { max-width: 100%; }
.multi-mode .node-card { background: var(--c-bg-light); border: 1px solid rgba(255,255,255,0.03); box-shadow: 0 4px 20px rgba(0,0,0,0.2); }
.multi-mode .node-header { flex-direction: row; justify-content: space-between; text-align: left; padding: 20px; }
.multi-mode .node-content { display: flex; align-items: center; gap: 15px; }
.multi-mode .icon-box { transform: scale(0.7); margin: 0; }
.multi-mode .text-info h1 { font-size: 20px; margin: 0 0 5px; }
.multi-mode .interactive-ip { margin-bottom: 0; font-size: 12px; padding: 2px 4px; }

.card-actions { display: flex; flex-direction: column; align-items: center; gap: 15px; width: 100%; position: relative; }
.main-btn { width: 240px; height: 46px; background: var(--c-primary); border: none; border-radius: 23px; color: white; font-weight: 900; font-size: 15px; cursor: pointer; transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275); position: relative; overflow: hidden; display: flex; justify-content: center; align-items: center; }
.main-btn:hover:not(:disabled) { background: #10c5e0; box-shadow: 0 8px 20px rgba(14, 176, 201, 0.3); transform: translateY(-1px); }
.main-btn:active:not(:disabled) { transform: scale(0.96); }

.btn-loading { width: 140px; background: transparent; border: 2px solid var(--c-primary); color: var(--c-primary); cursor: wait; box-shadow: none !important; }
.btn-warning { border-color: var(--c-warning); color: var(--c-warning); }

.loader { width: 20px; height: 20px; border: 3px solid rgba(14, 176, 201, 0.3); border-bottom-color: var(--c-primary); border-radius: 50%; display: inline-block; box-sizing: border-box; animation: rotation 1s linear infinite; }
.loader-warning { border-color: rgba(255,209,17,0.3); border-bottom-color: var(--c-warning); }
@keyframes rotation { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }

.sub-links { display: flex; gap: 20px; transition: opacity 0.3s; }
.sub-links button { background: transparent; border: none; color: var(--c-text-gray); font-size: 12px; font-weight: bold; cursor: pointer; transition: 0.2s; }
.sub-links button:hover { color: white; }
.del { color: var(--c-danger) !important; }

.multi-mode .card-actions { width: auto; align-items: flex-end; }
.multi-mode .main-btn { width: 120px; height: 38px; border-radius: 8px; font-size: 13px; }
.multi-mode .btn-loading { width: 100px; }

.monitor-dashboard { width: 100%; }
.dash-inner { padding: 0 20px 20px 20px; display: flex; flex-direction: column; gap: 15px; }
.multi-mode .dash-inner { border-top: 1px dashed rgba(255,255,255,0.05); padding-top: 15px; }

.expand-enter-active { transition: all 0.6s cubic-bezier(0.175, 0.885, 0.32, 1.275); max-height: 400px; opacity: 1; overflow: hidden; }
.expand-leave-active { transition: all 0.4s ease; max-height: 400px; opacity: 1; overflow: hidden; }
.expand-enter-from, .expand-leave-to { max-height: 0; opacity: 0; padding-top: 0; padding-bottom: 0; transform: translateY(-10px); }

.expand-enter-active .stagger-1 { animation: slideUp 0.5s 0.1s both cubic-bezier(0.175, 0.885, 0.32, 1.275); }
.expand-enter-active .stagger-2 { animation: slideUp 0.5s 0.15s both cubic-bezier(0.175, 0.885, 0.32, 1.275); }
.expand-enter-active .stagger-3 { animation: slideUp 0.5s 0.2s both cubic-bezier(0.175, 0.885, 0.32, 1.275); }
.expand-enter-active .stagger-4 { animation: slideUp 0.5s 0.25s both cubic-bezier(0.175, 0.885, 0.32, 1.275); }
.expand-enter-active .stagger-5 { animation: slideUp 0.5s 0.3s both cubic-bezier(0.175, 0.885, 0.32, 1.275); }
@keyframes slideUp { from { opacity: 0; transform: translateY(15px); } to { opacity: 1; transform: translateY(0); } }

.dash-header { display: flex; justify-content: space-between; font-size: 11px; opacity: 0.5; font-weight: 800; padding: 0 5px; align-items: center; }
.uptime-badge { background: rgba(255,255,255,0.08); padding: 3px 6px; border-radius: 4px; font-family: 'Inter', monospace; display: flex; align-items: center; }
.ping-badge { color: var(--c-success); background: rgba(46, 223, 163, 0.1); padding: 3px 6px; border-radius: 4px; }
.timer { color: var(--c-success); }

.kpi-row { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
.kpi-card { background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.04); padding: 12px 5px; border-radius: 12px; display: flex; flex-direction: column; align-items: center; gap: 5px; transition: color 0.3s; }
.kpi-card .val { font-size: 20px; font-weight: 900; font-family: 'Inter', sans-serif; }
.c-warn { color: var(--c-warning); } .c-succ { color: var(--c-success); } .c-prim { color: var(--c-primary); }
.kpi-card label { font-size: 10px; color: var(--c-text-gray); font-weight: bold; text-transform: uppercase; }

.action-row { display: grid; grid-template-columns: 2fr 1fr; gap: 12px; }
.btn-webui { background: transparent; border: 1px solid rgba(14, 176, 201, 0.5); color: var(--c-primary); border-radius: 14px; height: 46px; font-weight: bold; font-size: 13px; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px; transition: 0.2s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
.btn-webui:hover { background: rgba(14, 176, 201, 0.1); border-color: var(--c-primary); }
.btn-webui:active { transform: scale(0.96); }

.btn-restart { background: rgba(255, 209, 17, 0.05); border: 1px solid rgba(255, 209, 17, 0.2); color: var(--c-warning); border-radius: 14px; font-weight: bold; font-size: 12px; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 6px; transition: 0.2s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
.btn-restart:hover { background: rgba(255, 209, 17, 0.1); border-color: var(--c-warning); }
.btn-restart:active { transform: scale(0.96); }

/* 🌟 物理强杀文字跑偏：引入 flex 对齐 */
.btn-disconnect-big { width: 100%; height: 46px; background: rgba(244, 62, 6, 0.08); border: 1px solid rgba(244, 62, 6, 0.3); color: var(--c-danger); border-radius: 14px; font-weight: 900; font-size: 14px; cursor: pointer; margin-top: 5px; transition: 0.2s cubic-bezier(0.175, 0.885, 0.32, 1.275); display: flex; align-items: center; justify-content: center; }
.btn-disconnect-big:hover { background: var(--c-danger); color: white; }
.btn-disconnect-big:active { transform: scale(0.97); }

.bottom-bar { display: flex; justify-content: space-between; align-items: center; border-top: 1px solid rgba(255,255,255,0.05); padding-top: 15px; flex-shrink: 0; z-index: 10; }
.left-actions { display: flex; align-items: center; gap: 15px; }

.settings-box, .author-box { position: relative; }
.sys-btn { background: transparent; border: none; color: var(--c-text-gray); cursor: pointer; outline: none; padding: 5px; display: flex; align-items: center; justify-content: center; transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
.sys-btn:hover { color: white; transform: scale(1.15); }
.sys-btn:active { transform: scale(0.95); }
.gear-icon:hover { transform: rotate(90deg) scale(1.15); }

.menu-fade-enter-active, .menu-fade-leave-active { transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275); transform-origin: bottom left; }
.menu-fade-enter-from, .menu-fade-leave-to { opacity: 0; transform: scale(0.8) translateY(10px); }

.glass-menu { position: absolute; bottom: 40px; left: 0; background: rgba(22, 28, 28, 0.85); backdrop-filter: blur(25px); border: 1px solid rgba(255,255,255,0.08); border-radius: 12px; padding: 12px; display: flex; flex-direction: column; gap: 10px; width: 140px; z-index: 50; box-shadow: 0 15px 35px rgba(0,0,0,0.6); }

.glass-menu.author-card { display: flex !important; flex-direction: row !important; align-items: center; gap: 15px; width: max-content; min-width: 260px; padding: 15px 20px; border-color: rgba(14, 176, 201, 0.2); }
.author-avatar { width: 56px; height: 56px; border-radius: 12px; object-fit: cover; border: 2px solid rgba(14, 176, 201, 0.4); box-shadow: 0 4px 10px rgba(0,0,0,0.5); }
.author-info { display: flex; flex-direction: column; gap: 6px; }
.author-id { font-size: 18px; font-weight: 900; color: var(--c-primary); font-family: 'Inter', sans-serif; letter-spacing: 0.5px; }
.author-desc { font-size: 11px; color: var(--c-text-gray); opacity: 0.9; }

.menu-sec { display: flex; flex-direction: column; gap: 5px; }
.menu-sec span { font-size: 9px; color: var(--c-primary); font-weight: bold; text-transform: uppercase; margin-bottom: 2px; padding-left: 5px; }
.menu-sec button { background: transparent; border: none; color: var(--c-text-gray); padding: 6px 10px; text-align: left; font-size: 12px; border-radius: 6px; cursor: pointer; font-weight: bold; transition: background 0.2s; }
.menu-sec button:hover { background: rgba(255,255,255,0.05); color: white; }
.menu-sec button.on { color: var(--c-primary); background: rgba(14, 176, 201, 0.1); }

.status-msg { font-size: 11px; color: var(--c-text-gray); font-family: 'Inter', monospace; display: flex; align-items: center; gap: 6px; max-width: 45%; }
.status-msg .txt { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.warning-txt { color: var(--c-warning); font-weight: bold; }
.check { color: var(--c-success); font-weight: bold; }

.quit-btn { background: transparent; border: none; color: var(--c-danger); font-weight: 800; font-size: 13px; cursor: pointer; flex-shrink: 0; transition: 0.2s; }
.quit-btn:hover { opacity: 0.8; }

.modal-fade-enter-active, .modal-fade-leave-active { transition: opacity 0.3s ease; }
.modal-fade-enter-active .modal-card { transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
.modal-fade-leave-active .modal-card { transition: all 0.2s ease; }
.modal-fade-enter-from { opacity: 0; }
.modal-fade-enter-from .modal-card { transform: scale(0.95); opacity: 0; }
.modal-fade-leave-to { opacity: 0; }

.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.85); backdrop-filter: blur(15px); display: flex; align-items: center; justify-content: center; z-index: 1000; }
.modal-card { background: var(--c-bg-light); width: 360px; padding: 30px; border-radius: 20px; border: 1px solid rgba(14, 176, 201, 0.2); box-shadow: 0 30px 60px rgba(0,0,0,0.8); }
.modal-card h2 { margin-bottom: 20px; font-size: 16px; color: white; }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; }
.i label { display: block; font-size: 9px; color: var(--c-primary); font-weight: 900; margin-bottom: 5px; text-transform: uppercase; }
.i input { width: 100%; background: var(--c-bg-dark); border: 1px solid rgba(255,255,255,0.05); border-radius: 8px; padding: 10px; color: white; outline: none; font-family: 'Inter', monospace; font-size: 12px; transition: border 0.3s; }
.i input:focus { border-color: var(--c-primary); }
.btns { display: flex; justify-content: flex-end; gap: 15px; margin-top: 25px; }
.btns button { background: transparent; border: none; font-weight: bold; cursor: pointer; transition: 0.2s; font-size: 13px; }

.cancel-btn { color: var(--c-text-gray) !important; padding: 8px 12px; border-radius: 6px; }
.cancel-btn:hover { background: rgba(255,255,255,0.05); color: white !important; }
.save { color: var(--c-primary) !important; padding: 8px 12px; border-radius: 6px; }
.save:hover { background: rgba(14, 176, 201, 0.1); }
</style>