#!/bin/bash

# ==========================================
# TopSpeed Smart Panel - Auto Installer
# ==========================================

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
RESET="\e[0m"

# 1. Check Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run as root (sudo su)${RESET}"
  exit 1
fi

# 2. Check if already installed
if [ -d "/root/Smart-Panel" ] || [ -f "/usr/bin/topspeedsub" ]; then
    echo -e "${YELLOW}[!] TopSpeedSub is already installed!${RESET}"
    echo -e "${CYAN}[*] Running the Management Menu...${RESET}"
    sleep 2
    if [ -f "/usr/bin/topspeedsub" ]; then
        topspeedsub
    else
        echo -e "${RED}[!] Management script missing. Please reinstall.${RESET}"
    fi
    exit 0
fi

clear
echo -e "${CYAN}====================================================${RESET}"
echo -e "${GREEN}      Welcome to TopSpeed Smart Panel Installer     ${RESET}"
echo -e "${CYAN}====================================================${RESET}"
echo ""

# 3. Collect Variables
read -p "$(echo -e ${YELLOW}"[?] Enter Telegram Bot Token: "${RESET})" BOT_TOKEN
read -p "$(echo -e ${YELLOW}"[?] Enter Panel Port (e.g., 8081): "${RESET})" PANEL_PORT
read -p "$(echo -e ${YELLOW}"[?] Enter Panel Admin Username: "${RESET})" PANEL_USER
read -p "$(echo -e ${YELLOW}"[?] Enter Panel Admin Password: "${RESET})" PANEL_PASS

echo ""
echo -e "${GREEN}[+] Starting Installation... This may take a few minutes.${RESET}"

# 4. Install Prerequisites
echo -e "${CYAN}[*] Updating system and installing dependencies...${RESET}"
apt-get update -y -qq
apt-get install -y -qq python3 python3-venv python3-pip curl wget unzip sqlite3

# Install Xray-core for Tunnel context
if ! command -v xray &> /dev/null; then
    echo -e "${CYAN}[*] Installing Xray-core...${RESET}"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
fi

# 5. Setup Directory
echo -e "${CYAN}[*] Creating App Directories...${RESET}"
mkdir -p /root/Smart-Panel
cd /root/Smart-Panel

# 6. Generate Source Files
echo -e "${CYAN}[*] Generating Core Files...${RESET}"

# --- panel.html ---
cat << 'EOF' > panel.html
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>پنل مدیریت هوشمند</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400;700;900&display=swap');
        
        body { 
            font-family: 'Vazirmatn', sans-serif; 
            background-color: #121212; 
            color: #ffffff; 
            overflow-x: hidden;
            -webkit-tap-highlight-color: transparent;
        }
        
        .glass-panel { 
            background: #1c1c1e; 
            border: 1px solid #2c2c2e; 
            border-radius: 24px; 
            padding: 24px; 
            box-shadow: 0 10px 30px -10px rgba(0, 0, 0, 0.5);
        }

        .bottom-nav { 
            position: fixed; bottom: 0; left: 0; right: 0; 
            background: rgba(28, 28, 30, 0.98); 
            border-top: 1px solid #2c2c2e; 
            display: flex; justify-content: space-around; 
            padding: 12px 0 20px 0; z-index: 50; 
            border-radius: 24px 24px 0 0;
            box-shadow: 0 -10px 40px rgba(0,0,0,0.5);
        }
        
        .nav-item { 
            color: #8e8e93; display: flex; flex-direction: column; align-items: center; 
            font-size: 11px; gap: 6px; cursor: pointer; transition: all 0.3s ease;
            font-weight: bold;
        }
        .nav-item.active { color: #facc15; transform: translateY(-4px); }
        .nav-item i { font-size: 22px; transition: transform 0.3s; }
        
        input, select, textarea { 
            background: #2c2c2e; border: 1px solid #3a3a3c; 
            color: white; width: 100%; padding: 16px 18px; border-radius: 16px; margin-top: 6px; 
            outline: none; transition: all 0.3s; font-family: 'Vazirmatn', sans-serif;
        }
        input:focus, select:focus, textarea:focus { 
            border-color: #facc15; background: #3a3a3c; 
        }
        
        ::-webkit-scrollbar { width: 6px; height: 6px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: #3a3a3c; border-radius: 10px; }
        ::-webkit-scrollbar-thumb:hover { background: #48484a; }

        details > summary { list-style: none; user-select: none; }
        details > summary::-webkit-details-marker { display: none; }
        details[open] summary ~ * { animation: slideDown 0.3s ease-out; }
        @keyframes slideDown { 
            from { opacity: 0; transform: translateY(-10px); } 
            to { opacity: 1; transform: translateY(0); } 
        }

        .toast { 
            position: fixed; top: 20px; left: 50%; transform: translateX(-50%) translateY(-20px); 
            background: #facc15; color: black; 
            padding: 14px 28px; border-radius: 100px; z-index: 1000; opacity: 0; 
            visibility: hidden; transition: all 0.4s cubic-bezier(0.68, -0.55, 0.265, 1.55);
            font-weight: bold; box-shadow: 0 10px 30px rgba(250, 204, 21, 0.3);
        }
        .toast.show { opacity: 1; visibility: visible; transform: translateX(-50%) translateY(0); }
        .toast.error { background: #ff453a; color: white; box-shadow: 0 10px 30px rgba(255, 69, 58, 0.3); }
        
        .top-header {
            position: fixed; top: 0; left: 0; right: 0; z-index: 40;
            background: linear-gradient(to bottom, #121212 0%, rgba(18,18,18,0.9) 70%, rgba(18,18,18,0) 100%);
            padding: 20px 20px 30px 20px;
        }
    </style>
</head>
<body>
    <div id="toast" class="toast">عملیات با موفقیت انجام شد</div>
    
    <!-- صفحه ورود -->
    <div id="login-screen" class="min-h-screen flex items-center justify-center p-4 bg-[#121212]">
        <div class="w-full max-w-sm text-center bg-[#1c1c1e] border border-[#2c2c2e] rounded-3xl p-8 shadow-2xl">
            <div class="w-20 h-20 rounded-full flex items-center justify-center mx-auto mb-6 border border-[#2c2c2e] bg-[#2c2c2e]">
                <i class="fas fa-fingerprint text-4xl text-[#facc15]"></i>
            </div>
            <h2 class="text-2xl font-black mb-8 text-white">مدیریت دیتای بات</h2>
            <input type="text" id="username" placeholder="نام کاربری" class="mb-4 text-left text-lg bg-[#2c2c2e] border-none rounded-2xl py-4" dir="ltr">
            <input type="password" id="password" placeholder="رمز عبور" class="mb-8 text-left text-lg bg-[#2c2c2e] border-none rounded-2xl py-4" dir="ltr">
            <button onclick="login()" class="w-full bg-[#facc15] hover:bg-[#eab308] text-black font-black py-4 px-4 rounded-2xl transition-colors text-lg">
                ورود
            </button>
        </div>
    </div>

    <!-- بدنه اصلی اپلیکیشن -->
    <div id="main-app" class="hidden max-w-lg mx-auto relative pt-24 pb-32 px-4">
        
        <div class="top-header max-w-lg mx-auto flex justify-between items-center">
            <div class="text-2xl font-black text-[#facc15]" id="header-title">داشبورد</div>
            <button onclick="logout()" class="w-10 h-10 rounded-full bg-[#2c2c2e] text-[#8e8e93] hover:text-white flex items-center justify-center transition-all">
                <i class="fas fa-power-off"></i>
            </button>
        </div>

        <div id="page-dashboard" class="space-y-5">
            <div class="grid grid-cols-3 gap-3">
                <div class="glass-panel text-center p-4">
                    <i class="fas fa-users text-2xl text-[#8e8e93] mb-2"></i>
                    <div class="text-[10px] text-[#8e8e93] font-bold mb-1">کاربران ربات</div>
                    <div class="text-2xl font-black text-white" id="dash-users">0</div>
                </div>
                <div class="glass-panel text-center p-4 border-[#32d74b]/30">
                    <i class="fas fa-globe text-2xl text-[#32d74b] mb-2"></i>
                    <div class="text-[10px] text-[#32d74b] font-bold mb-1">آنلاین لحظه‌ای</div>
                    <div class="text-2xl font-black text-[#32d74b]" id="dash-online">0</div>
                </div>
                <div class="glass-panel text-center p-4">
                    <i class="fas fa-server text-2xl text-[#facc15] mb-2"></i>
                    <div class="text-[10px] text-[#8e8e93] font-bold mb-1">سرورها</div>
                    <div class="text-2xl font-black text-white" id="dash-servers-count">0</div>
                </div>
            </div>

            <div class="glass-panel p-5">
                <h3 class="text-[#facc15] font-bold mb-4 flex items-center"><i class="fas fa-chart-pie ml-2"></i> آمار تفکیکی سرورها</h3>
                <div id="stats-list" class="space-y-2"></div>
            </div>

            <details class="glass-panel !p-0 group overflow-hidden border-[#ff9f0a]/30 mb-4">
                <summary class="flex justify-between items-center p-5 cursor-pointer bg-[#2c2c2e]/50 hover:bg-[#2c2c2e] transition-colors">
                    <h3 class="text-[#ff9f0a] m-0 font-bold flex items-center"><i class="fas fa-hourglass-half ml-2"></i> انقضا در ۲۴ ساعت آینده</h3>
                    <div class="flex items-center gap-3">
                        <span id="exp-count-badge" class="bg-[#ff9f0a]/20 text-[#ff9f0a] px-3 py-1 rounded-lg text-sm font-black">0</span>
                        <div class="w-6 h-6 rounded-full bg-[#3a3a3c] flex items-center justify-center transition-transform duration-300 group-open:rotate-180">
                            <i class="fas fa-chevron-down text-white text-xs"></i>
                        </div>
                    </div>
                </summary>
                <div class="border-t border-[#3a3a3c] p-4 bg-[#1c1c1e]">
                    <div id="exp-list" class="space-y-3 max-h-80 overflow-y-auto pr-2"></div>
                </div>
            </details>

            <details class="glass-panel !p-0 group overflow-hidden border-[#ff453a]/30">
                <summary class="flex justify-between items-center p-5 cursor-pointer bg-[#2c2c2e]/50 hover:bg-[#2c2c2e] transition-colors">
                    <h3 class="text-[#ff453a] m-0 font-bold flex items-center"><i class="fas fa-skull-crossbones ml-2"></i> منقضی‌های بالای ۴۸ ساعت</h3>
                    <div class="flex items-center gap-3">
                        <span id="expired-48h-badge" class="bg-[#ff453a] text-white px-3 py-1 rounded-lg text-sm font-black">0</span>
                        <div class="w-6 h-6 rounded-full bg-[#3a3a3c] flex items-center justify-center transition-transform duration-300 group-open:rotate-180">
                            <i class="fas fa-chevron-down text-white text-xs"></i>
                        </div>
                    </div>
                </summary>
                <div class="border-t border-[#3a3a3c] p-4 bg-[#1c1c1e]">
                    <div id="expired-48h-list" class="space-y-2 max-h-72 overflow-y-auto pr-2 mb-4"></div>
                    <button onclick="deleteAll48h()" id="btn-del-48h" class="w-full bg-[#ff453a] hover:bg-[#d70015] text-white font-bold py-4 rounded-xl transition-colors flex justify-center items-center gap-2 hidden">
                        <i class="fas fa-trash-can text-lg"></i> پاکسازی گروهی از تمام سرورها
                    </button>
                </div>
            </details>
        </div>

        <div id="page-servers" class="hidden space-y-5">
            <button onclick="openServerModal()" class="w-full bg-[#2c2c2e] hover:bg-[#3a3a3c] text-[#facc15] font-bold py-5 rounded-2xl transition-all border border-dashed border-[#facc15]/50 flex justify-center items-center gap-2">
                <i class="fas fa-plus-circle text-xl"></i> افزودن سرور جدید
            </button>
            <div id="servers-list" class="space-y-4"></div>
        </div>

        <div id="page-messages" class="hidden space-y-5">
            <div class="glass-panel p-6 bg-[#1c1c1e]">
                <h3 class="text-[#facc15] font-bold mb-6 flex items-center text-lg"><i class="fas fa-bullhorn ml-2"></i> سیستم اطلاع‌رسانی همگانی</h3>
                
                <label class="text-xs font-bold text-[#8e8e93] ml-1 mb-2 block">گروه هدف</label>
                <select id="msg-target" class="mb-6 bg-[#2c2c2e] py-4">
                    <option value="all">تمامی کاربران بات</option>
                </select>
                
                <label class="text-xs font-bold text-[#8e8e93] ml-1 mb-2 block">متن پیام</label>
                <textarea id="msg-text" rows="5" class="mb-8 bg-[#2c2c2e] py-4 resize-none" placeholder="پیام خود را اینجا بنویسید..."></textarea>
                
                <button onclick="sendBroadcast()" class="w-full bg-[#facc15] hover:bg-[#eab308] text-black font-black py-4 rounded-xl transition-colors flex items-center justify-center gap-2">
                    <i class="fas fa-paper-plane"></i> ارسال پیام
                </button>
            </div>
        </div>

        <div id="page-settings" class="hidden space-y-5">
            <div class="glass-panel p-6 text-center mb-5">
                <div class="w-16 h-16 bg-[#0a84ff]/20 rounded-full flex items-center justify-center mx-auto mb-4 border border-[#0a84ff]/30">
                    <i class="fas fa-database text-2xl text-[#0a84ff]"></i>
                </div>
                <h3 class="text-white font-bold mb-2">مدیریت دیتابیس</h3>
                <p class="text-xs text-[#8e8e93] mb-6 leading-relaxed">جهت جلوگیری از دست رفتن اطلاعات، به صورت دوره‌ای از دیتابیس ربات نسخه پشتیبان تهیه کنید.</p>
                <div class="space-y-3">
                    <button onclick="downloadBackup()" class="w-full bg-[#2c2c2e] hover:bg-[#3a3a3c] text-[#0a84ff] font-bold py-4 rounded-xl transition-colors flex items-center justify-center gap-2">
                        <i class="fas fa-cloud-arrow-down text-lg"></i> دریافت نسخه پشتیبان
                    </button>
                    <div class="relative w-full">
                        <input type="file" id="restore-file" class="hidden" accept=".db">
                        <button onclick="document.getElementById('restore-file').click()" class="w-full bg-[#1c1c1e] hover:bg-[#2c2c2e] border border-[#3a3a3c] text-white font-bold py-4 rounded-xl transition-colors flex items-center justify-center gap-2">
                            <i class="fas fa-cloud-arrow-up text-lg"></i> بازگردانی دیتابیس
                        </button>
                    </div>
                </div>
            </div>

            <div class="glass-panel p-6 bg-[#1c1c1e]">
                <h3 class="text-[#facc15] font-bold mb-4 flex items-center text-lg"><i class="fas fa-robot ml-2"></i> مانیتورینگ و گزارش‌دهی</h3>
                <p class="text-xs text-[#8e8e93] mb-6 leading-relaxed">با وارد کردن اطلاعات زیر، سیستم قطعی سرورها یا رسیدن آنلاین‌ها به صفر را در گروه کاری شما گزارش می‌دهد.</p>
                
                <label class="text-[12px] font-bold text-[#8e8e93] ml-1 block mb-2">توکن ربات گزارش‌دهی (Admin Bot)</label>
                <input type="text" id="admin-bot-token" placeholder="مثال: 123456:ABC-DEF..." class="text-left bg-[#2c2c2e] border-[#3a3a3c] rounded-2xl py-4 text-white mb-4" dir="ltr">
                
                <label class="text-[12px] font-bold text-[#8e8e93] ml-1 block mb-2">آیدی گروه / چت (Chat ID)</label>
                <input type="text" id="admin-chat-id" placeholder="مثال: -100123456789" class="text-left bg-[#2c2c2e] border-[#3a3a3c] rounded-2xl py-4 text-white mb-6" dir="ltr">
                
                <button onclick="saveAdminSettings()" class="w-full bg-[#2c2c2e] hover:bg-[#3a3a3c] text-[#facc15] font-bold py-4 rounded-xl transition-colors flex items-center justify-center gap-2 border border-[#facc15]/30">
                    <i class="fas fa-save"></i> ذخیره تنظیمات مانیتورینگ
                </button>
            </div>
        </div>
    </div>

    <div id="server-modal" class="fixed inset-0 bg-black/90 hidden z-[100] flex items-center justify-center p-4">
        <div class="w-full max-w-sm bg-[#1c1c1e] border border-[#2c2c2e] rounded-[32px] p-8 shadow-2xl">
            <h3 class="text-2xl font-black mb-8 text-[#facc15] flex items-center" id="server-modal-title">
                <i class="fas fa-plus-circle ml-2 text-xl"></i>افزودن سرور جدید
            </h3>
            <input type="hidden" id="srv-id">
            
            <div class="space-y-5">
                <div>
                    <label class="text-[12px] font-bold text-[#8e8e93] ml-1 block mb-2">نام نمایشی (اختیاری)</label>
                    <input type="text" id="srv-name" placeholder="مثال: سرور آلمان ۱" class="bg-[#2c2c2e] border-[#3a3a3c] rounded-2xl py-4 text-white">
                </div>
                <div>
                    <label class="text-[12px] font-bold text-[#8e8e93] ml-1 block mb-2">آدرس پنل (شامل پروتکل و پورت)</label>
                    <input type="text" id="srv-host" placeholder="https://87...:14099/path" class="text-left bg-[#2c2c2e] border-[#3a3a3c] rounded-2xl py-4 text-white" dir="ltr">
                </div>
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="text-[12px] font-bold text-[#8e8e93] ml-1 block mb-2">نام کاربری</label>
                        <input type="text" id="srv-user" placeholder="admin" class="text-left bg-[#2c2c2e] border-[#3a3a3c] rounded-2xl py-4 text-white" dir="ltr">
                    </div>
                    <div>
                        <label class="text-[12px] font-bold text-[#8e8e93] ml-1 block mb-2">رمز عبور</label>
                        <input type="password" id="srv-pass" class="text-left bg-[#2c2c2e] border-[#3a3a3c] rounded-2xl py-4 text-white" dir="ltr">
                    </div>
                </div>
                <div>
                    <label class="text-[12px] font-bold text-[#8e8e93] ml-1 block mb-2">مسیر امن Vless (جهت دور زدن فیلترینگ)</label>
                    <textarea id="srv-xray" rows="2" placeholder="vless://..." class="text-left text-[11px] bg-[#2c2c2e] border-[#3a3a3c] rounded-2xl py-4 text-white resize-none" dir="ltr"></textarea>
                </div>
            </div>
            
            <div class="flex gap-4 mt-8">
                <button onclick="saveServer()" class="flex-[2] bg-[#facc15] hover:bg-[#eab308] text-black font-black py-4 rounded-2xl transition-colors text-lg">ثبت اطلاعات</button>
                <button onclick="closeServerModal()" class="flex-[1] bg-[#2c2c2e] hover:bg-[#3a3a3c] text-white font-bold py-4 rounded-2xl transition-colors">انصراف</button>
            </div>
        </div>
    </div>

    <div class="bottom-nav hidden" id="bottom-nav">
        <div class="nav-item active" onclick="nav('dashboard')" id="nav-dashboard">
            <i class="fas fa-chart-pie"></i><span>داشبورد</span>
        </div>
        <div class="nav-item" onclick="nav('servers')" id="nav-servers">
            <i class="fas fa-server"></i><span>سرورها</span>
        </div>
        <div class="nav-item" onclick="nav('messages')" id="nav-messages">
            <i class="fas fa-paper-plane"></i><span>پیام‌ها</span>
        </div>
        <div class="nav-item" onclick="nav('settings')" id="nav-settings">
            <i class="fas fa-gear"></i><span>تنظیمات</span>
        </div>
    </div>

    <script>
        function showToast(msg, isError = false) {
            const toast = document.getElementById('toast');
            toast.textContent = msg;
            toast.className = isError ? 'toast error show' : 'toast show';
            setTimeout(() => toast.classList.remove('show'), 3000);
        }

        async function api(path, options = {}) {
            try {
                const res = await fetch('/api' + path, {
                    ...options,
                    headers: { 'Content-Type': 'application/json', ...options.headers }
                });
                return await res.json();
            } catch (e) {
                showToast("خطا در ارتباط با سرور", true);
                return null;
            }
        }

        window.onload = function() {
            if(localStorage.getItem('topspeed_logged_in') === 'true') {
                document.getElementById('login-screen').classList.add('hidden');
                document.getElementById('main-app').classList.remove('hidden');
                document.getElementById('bottom-nav').classList.remove('hidden');
                refreshAll();
            }
        };

        async function login() {
            const u = document.getElementById('username').value;
            const p = document.getElementById('password').value;
            const btn = document.querySelector('#login-screen button');
            btn.innerHTML = '<i class="fas fa-circle-notch fa-spin"></i>';
            
            const res = await api('/login', { method: 'POST', body: JSON.stringify({username: u, password: p}) });
            if (res && res.success) {
                localStorage.setItem('topspeed_logged_in', 'true');
                document.getElementById('login-screen').classList.add('hidden');
                document.getElementById('main-app').classList.remove('hidden');
                document.getElementById('bottom-nav').classList.remove('hidden');
                refreshAll();
            } else {
                showToast("اطلاعات ورود اشتباه است", true);
                btn.innerHTML = 'ورود';
            }
        }

        function logout() { 
            localStorage.removeItem('topspeed_logged_in');
            location.reload(); 
        }

        const pages = {
            'dashboard': 'داشبورد',
            'servers': 'مدیریت سرورها',
            'messages': 'اطلاع‌رسانی',
            'settings': 'تنظیمات سیستم'
        };

        function nav(page) {
            Object.keys(pages).forEach(p => {
                document.getElementById('page-' + p).classList.add('hidden');
                document.getElementById('nav-' + p).classList.remove('active');
            });
            document.getElementById('page-' + page).classList.remove('hidden');
            document.getElementById('nav-' + page).classList.add('active');
            document.getElementById('header-title').innerHTML = pages[page];
            window.scrollTo({ top: 0, behavior: 'smooth' });
            
            if(page === 'dashboard') fetchDashboard();
            if(page === 'servers') fetchServers();
            if(page === 'settings') fetchAdminSettings();
        }

        function copyToClipboard(text, btnElement) {
            const fallbackCopy = (text) => {
                var textArea = document.createElement("textarea");
                textArea.value = text;
                textArea.style.position = "fixed";
                textArea.style.top = "0";
                textArea.style.left = "0";
                textArea.style.opacity = "0";
                document.body.appendChild(textArea);
                textArea.focus();
                textArea.select();
                try {
                    var successful = document.execCommand('copy');
                    if (successful) showSuccess(btnElement);
                    else showToast('خطا در کپی', true);
                } catch (err) {
                    showToast('امکان کپی در مرورگر شما نیست', true);
                }
                document.body.removeChild(textArea);
            };

            if (navigator.clipboard && window.isSecureContext) {
                navigator.clipboard.writeText(text).then(() => {
                    showSuccess(btnElement);
                }).catch(() => {
                    fallbackCopy(text);
                });
            } else {
                fallbackCopy(text);
            }
        }

        function showSuccess(btnElement) {
            const icon = btnElement.querySelector('i');
            icon.className = 'fas fa-check text-[#32d74b]';
            showToast('لینک UUID کپی شد');
            setTimeout(() => { icon.className = 'fas fa-copy'; }, 2000);
        }

        async function fetchDashboard() {
            const data = await api('/dashboard');
            if(!data) return;
            
            document.getElementById('dash-users').textContent = data.total_users;
            document.getElementById('dash-servers-count').textContent = data.total_servers;
            document.getElementById('dash-online').textContent = data.total_online;
            
            const statsHtml = data.user_stats.map(s => `
                <div class="flex justify-between items-center bg-[#2c2c2e] p-4 rounded-2xl border border-[#3a3a3c]">
                    <span class="text-sm font-bold text-white">${s.record}</span>
                    <span class="bg-[#facc15]/20 text-[#facc15] px-3 py-1 rounded-lg text-xs font-black">${s.count} کاربر</span>
                </div>
            `).join('');
            document.getElementById('stats-list').innerHTML = statsHtml || '<div class="text-center text-sm text-[#8e8e93] py-4">کاربری ثبت نشده است</div>';

            document.getElementById('exp-count-badge').textContent = data.expiring_soon.length;
            const expHtml = data.expiring_soon.map(e => {
                const hours = ((e.expiry - data.now) / 3600000).toFixed(1);
                return `
                <div class="bg-[#2c2c2e] border border-[#ff9f0a]/30 p-4 rounded-2xl">
                    <div class="flex justify-between items-start mb-2">
                        <div class="text-white font-bold text-sm truncate pr-2" dir="ltr">${e.email}</div>
                        <div class="text-[#ff9f0a] text-xs font-black bg-[#ff9f0a]/20 px-2 py-1 rounded-lg">
                            ${hours} ساعت
                        </div>
                    </div>
                    <div class="text-[10px] text-[#8e8e93] mb-3 flex items-center"><i class="fas fa-server ml-1"></i> ${e.server_host}</div>
                    <div class="flex items-center justify-between bg-[#1c1c1e] rounded-xl p-2 border border-[#3a3a3c]">
                        <span class="text-[10px] text-[#8e8e93] truncate font-mono" dir="ltr">${e.uuid}</span>
                        <button onclick="copyToClipboard('${e.uuid}', this)" class="text-[#8e8e93] hover:text-[#facc15] w-8 h-8 rounded-lg bg-[#2c2c2e] flex items-center justify-center transition-colors">
                            <i class="fas fa-copy"></i>
                        </button>
                    </div>
                </div>`;
            }).join('');
            document.getElementById('exp-list').innerHTML = expHtml || '<div class="text-center text-sm text-[#8e8e93] py-6">موردی یافت نشد</div>';

            fetchExpired48h();
        }

        async function fetchExpired48h() {
            const data = await api('/expired_48h');
            if(!data) return;
            
            document.getElementById('expired-48h-badge').textContent = data.length;
            const btn = document.getElementById('btn-del-48h');
            
            if(data.length > 0) {
                btn.classList.remove('hidden');
                const listHtml = data.map(e => `
                    <div class="flex justify-between items-center bg-[#2c2c2e] p-4 border border-[#ff453a]/20 rounded-2xl">
                        <div class="truncate text-sm font-bold text-white w-2/3" dir="ltr">${e.email}</div>
                        <div class="text-[10px] text-[#8e8e93] flex items-center gap-1 bg-[#1c1c1e] px-2 py-1 rounded-lg"><i class="fas fa-server"></i> ${e.server_host}</div>
                    </div>
                `).join('');
                document.getElementById('expired-48h-list').innerHTML = listHtml;
            } else {
                btn.classList.add('hidden');
                document.getElementById('expired-48h-list').innerHTML = '<div class="text-center text-sm text-[#8e8e93] py-6">موردی یافت نشد</div>';
            }
        }

        async function deleteAll48h() {
            if(!confirm("آیا از پاکسازی گروهی و دائمی این کاربران از تمام پنل‌ها اطمینان دارید؟")) return;
            
            const btn = document.getElementById('btn-del-48h');
            const originalText = btn.innerHTML;
            btn.innerHTML = '<i class="fas fa-circle-notch fa-spin text-xl"></i> در حال پاکسازی...';
            btn.disabled = true;

            const res = await api('/expired_48h', { method: 'DELETE' });
            if(res && res.status === 'success') {
                showToast(`عملیات موفق: ${res.deleted} کاربر حذف شد.`);
                fetchDashboard();
            } else {
                showToast('خطا در ارتباط با سرور', true);
            }
            
            btn.innerHTML = originalText;
            btn.disabled = false;
        }

        async function fetchServers() {
            const servers = await api('/servers');
            if(!servers) return;
            
            const sel = document.getElementById('msg-target');
            sel.innerHTML = '<option value="all">تمامی کاربران بات</option>';
            servers.forEach(s => {
                let displayName = s.name ? s.name : s.host;
                sel.innerHTML += `<option value="${s.host}">${displayName}</option>`;
            });

            document.getElementById('servers-list').innerHTML = servers.map(s => `
                <div class="glass-panel relative p-5">
                    <div class="absolute top-5 left-5 flex gap-2">
                        <button onclick="editServer(${s.id})" class="w-8 h-8 rounded-full bg-[#0a84ff]/20 text-[#0a84ff] hover:bg-[#0a84ff] hover:text-white flex items-center justify-center transition-all"><i class="fas fa-pen text-xs"></i></button>
                        <button onclick="deleteServer(${s.id})" class="w-8 h-8 rounded-full bg-[#ff453a]/20 text-[#ff453a] hover:bg-[#ff453a] hover:text-white flex items-center justify-center transition-all"><i class="fas fa-trash text-xs"></i></button>
                    </div>
                    <div class="flex items-center gap-3 mb-4">
                        <div class="w-10 h-10 rounded-xl bg-[#facc15]/20 flex items-center justify-center border border-[#facc15]/30">
                            <i class="fas fa-network-wired text-[#facc15]"></i>
                        </div>
                        <div>
                            <div class="font-black text-white text-lg">${s.name || 'بدون نام'}</div>
                            <div class="text-[10px] text-[#8e8e93] font-mono" dir="ltr">${s.host}</div>
                        </div>
                    </div>
                    <div class="bg-[#2c2c2e] rounded-xl p-3 flex justify-between items-center border border-[#3a3a3c]">
                        <div class="flex items-center gap-2">
                            <i class="fas fa-users text-[#8e8e93] text-xs"></i>
                            <span class="text-xs text-[#8e8e93]">آنلاین:</span>
                            <span class="text-[#32d74b] font-black">${s.online_count || 0}</span>
                        </div>
                        ${s.xray_config ? '<span class="bg-[#32d74b]/20 text-[#32d74b] border border-[#32d74b]/30 px-2 py-1 rounded-lg text-[10px] font-bold flex items-center gap-1"><i class="fas fa-shield-check"></i> تونل فعال</span>' : '<span class="bg-[#3a3a3c] text-white px-2 py-1 rounded-lg text-[10px]">مستقیم</span>'}
                    </div>
                </div>
            `).join('');
        }

        async function editServer(id) {
            const servers = await api('/servers');
            const s = servers.find(x => x.id === id);
            if(s) {
                document.getElementById('srv-id').value = s.id;
                document.getElementById('srv-name').value = s.name;
                document.getElementById('srv-host').value = s.host;
                document.getElementById('srv-user').value = s.user;
                document.getElementById('srv-pass').value = s.password;
                document.getElementById('srv-xray').value = s.xray_config;
                document.getElementById('server-modal-title').innerHTML = '<i class="fas fa-pen-to-square ml-2 text-xl"></i>ویرایش سرور';
                document.getElementById('server-modal').classList.remove('hidden');
            }
        }

        function openServerModal() {
            document.getElementById('srv-id').value = '';
            document.getElementById('srv-name').value = '';
            document.getElementById('srv-host').value = '';
            document.getElementById('srv-user').value = '';
            document.getElementById('srv-pass').value = '';
            document.getElementById('srv-xray').value = '';
            document.getElementById('server-modal-title').innerHTML = '<i class="fas fa-plus-circle ml-2 text-xl"></i>افزودن سرور جدید';
            document.getElementById('server-modal').classList.remove('hidden');
        }

        function closeServerModal() { document.getElementById('server-modal').classList.add('hidden'); }

        async function saveServer() {
            const data = {
                name: document.getElementById('srv-name').value,
                host: document.getElementById('srv-host').value,
                user: document.getElementById('srv-user').value,
                password: document.getElementById('srv-pass').value,
                xray_config: document.getElementById('srv-xray').value
            };
            if(!data.host || !data.user || !data.password) return showToast('فیلدهای ضروری را پر کنید', true);
            
            const btn = document.querySelector('#server-modal button');
            const originalText = btn.innerHTML;
            btn.innerHTML = '<i class="fas fa-circle-notch fa-spin"></i>';
            btn.disabled = true;

            const id = document.getElementById('srv-id').value;
            const res = id ? await api('/servers/'+id, {method:'PUT', body:JSON.stringify(data)}) 
                         : await api('/servers', {method:'POST', body:JSON.stringify(data)});
            
            btn.innerHTML = originalText;
            btn.disabled = false;

            if(res && res.status === 'success') {
                showToast('اطلاعات ذخیره شد');
                closeServerModal();
                fetchServers();
            }
        }

        async function deleteServer(id) {
            if(!confirm('آیا از حذف این سرور اطمینان دارید؟')) return;
            const res = await api('/servers/'+id, {method:'DELETE'});
            if(res && res.status === 'success') { showToast('سرور حذف شد'); fetchServers(); }
        }

        async function sendBroadcast() {
            const msg = document.getElementById('msg-text').value;
            if(!msg) return showToast('متن پیام خالی است', true);
            const target = document.getElementById('msg-target').value;
            
            const btn = document.querySelector('#page-messages button');
            const originalText = btn.innerHTML;
            btn.innerHTML = '<i class="fas fa-circle-notch fa-spin"></i> در حال پردازش...';
            btn.disabled = true;

            const res = await api('/broadcast', {method:'POST', body:JSON.stringify({message: msg, target_server: target})});
            
            btn.innerHTML = originalText;
            btn.disabled = false;

            if(res && res.status === 'success') {
                showToast('پیام در صف ارسال قرار گرفت');
                document.getElementById('msg-text').value = '';
            }
        }

        async function fetchAdminSettings() {
            const data = await api('/settings');
            if(data) {
                document.getElementById('admin-bot-token').value = data.admin_bot_token || '';
                document.getElementById('admin-chat-id').value = data.admin_chat_id || '';
            }
        }

        async function saveAdminSettings() {
            const t = document.getElementById('admin-bot-token').value;
            const c = document.getElementById('admin-chat-id').value;
            const res = await api('/settings', {method: 'POST', body: JSON.stringify({admin_bot_token: t, admin_chat_id: c})});
            if(res && res.status === 'success') showToast('تنظیمات مانیتورینگ ذخیره شد');
        }

        function downloadBackup() { window.location.href = '/api/backup'; }
        
        document.getElementById('restore-file').addEventListener('change', async (e) => {
            const file = e.target.files[0];
            if(!file) return;
            const fd = new FormData(); fd.append('file', file);
            
            showToast('در حال بازگردانی دیتابیس...');
            const res = await fetch('/api/restore', {method:'POST', body: fd});
            if(res.ok) { 
                showToast('بازگردانی با موفقیت انجام شد'); 
                fetchDashboard(); 
            } else {
                showToast('خطا در بازگردانی', true);
            }
            e.target.value = '';
        });

        function refreshAll() { fetchDashboard(); fetchServers(); }
        setInterval(() => { 
            if(!document.getElementById('main-app').classList.contains('hidden') && 
                !document.getElementById('page-dashboard').classList.contains('hidden')) {
                fetchDashboard(); 
            }
        }, 30000);
    </script>
</body>
</html>
EOF

# --- xray_bot.py ---
cat << 'EOF' > xray_bot.py
import sqlite3
import telebot
from telebot import types
import os
import requests
import urllib3
import time
import threading
import json
import urllib.parse
from urllib.parse import urlparse, parse_qs
import socket
import re
import subprocess

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

BOT_TOKEN = "BOT_TOKEN_PLACEHOLDER"
ADMIN_ID = 1735582050
REQUIRED_CHANNELS = ["@top_speed_vpn", "@Topspeed_Free"]
CHECK_INTERVAL_SECONDS = 15
DB_PATH = "users.db"

bot = telebot.TeleBot(BOT_TOKEN, threaded=True)

# حافظه وضعیت برای مانیتورینگ ادمین
server_states = {}

def get_db():
    conn = sqlite3.connect(DB_PATH, timeout=20)
    conn.execute('PRAGMA journal_mode=WAL;')
    conn.row_factory = sqlite3.Row
    return conn

def send_admin_alert(text):
    try:
        conn = get_db()
        c = conn.cursor()
        c.execute("SELECT value FROM settings WHERE key='admin_bot_token'")
        token_row = c.fetchone()
        c.execute("SELECT value FROM settings WHERE key='admin_chat_id'")
        chat_row = c.fetchone()
        conn.close()
        
        if token_row and chat_row:
            token = token_row['value']
            chat_id = chat_row['value']
            if token and chat_id:
                requests.post(f"https://api.telegram.org/bot{token}/sendMessage", json={"chat_id": chat_id, "text": text})
    except Exception as e:
        pass

def get_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('', 0))
        return s.getsockname()[1]

def build_xray_outbound(vless_link):
    vless_link = vless_link.strip()
    if not vless_link.lower().startswith("vless://"): return None
    vless_link = "vless://" + vless_link[8:]
    parsed = urllib.parse.urlparse(vless_link)
    uuid_val = parsed.username
    address = parsed.hostname
    port = parsed.port
    if not uuid_val or not address or not port: return None
    qs = parse_qs(parsed.query, keep_blank_values=True)
    def get_qs(key, default=""): 
        val = qs.get(key, [""])[0]
        return val if val != "" else default
    
    network = get_qs("type", "tcp")
    security = get_qs("security", "none")
    sni = get_qs("sni", "")
    fp = get_qs("fp", "")
    pbk = get_qs("pbk", "")
    sid = get_qs("sid", "")
    path = get_qs("path", "")
    host = get_qs("host", "")
    
    outbound = {
        "protocol": "vless",
        "settings": {"vnext": [{"address": address, "port": int(port), "users": [{"id": uuid_val, "encryption": "none"}]}]},
        "streamSettings": {"network": network, "security": security}
    }
    if security == "tls":
        outbound["streamSettings"]["tlsSettings"] = {"serverName": sni or host or address, "fingerprint": fp}
    elif security == "reality":
        outbound["streamSettings"]["realitySettings"] = {"serverName": sni or host or address, "fingerprint": fp, "publicKey": pbk, "shortId": sid, "spiderX": get_qs("spx", "/")}
    if network == "ws":
        outbound["streamSettings"]["wsSettings"] = {"path": path, "headers": {"Host": host} if host else {}}
    return outbound

class XrayTunnelContext:
    def __init__(self, vless_link):
        self.vless_link = vless_link
        self.process = None
        self.local_port = None

    def __enter__(self):
        if not self.vless_link or not self.vless_link.strip().lower().startswith("vless://"):
            return None
        outbound = build_xray_outbound(self.vless_link)
        if not outbound: return None
        
        self.local_port = get_free_port()
        config = {
            "log": {"loglevel": "warning"},
            "inbounds": [{"port": self.local_port, "listen": "127.0.0.1", "protocol": "socks", "settings": {"udp": True}}],
            "outbounds": [outbound]
        }
        config_path = f'/tmp/xray_config_{self.local_port}.json'
        with open(config_path, 'w') as f: json.dump(config, f)
        
        self.process = subprocess.Popen(['/usr/local/bin/xray', 'run', '-c', config_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(2)
        if self.process.poll() is not None: return None
        return f"socks5://127.0.0.1:{self.local_port}"

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.process:
            try: 
                self.process.terminate()
                self.process.wait()
            except: pass

def check_membership(user_id):
    not_member = []
    try:
        for ch in REQUIRED_CHANNELS:
            if bot.get_chat_member(ch, user_id).status not in ['member', 'administrator', 'creator']:
                not_member.append(ch)
    except:
        return REQUIRED_CHANNELS
    return not_member

def get_main_keyboard():
    markup = types.ReplyKeyboardMarkup(resize_keyboard=True, row_width=1)
    markup.add("دریافت لینک سابسکرایبشن 🔗", "استعلام مستقیم حجم و زمان 📊", "استارت مجدد ربات 🔄")
    return markup

def is_menu_button(txt):
    return any(word in txt for word in ["استعلام", "دریافت", "استارت", "/start", "مجدد"])

def save_user(user_id, username, record=None):
    # این عملیات حالا چون دیتابیس قفل نیست در کسری از ثانیه انجام میشود
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('INSERT OR IGNORE INTO users (user_id, username) VALUES (?, ?)', (user_id, username))
    if record:
        cursor.execute('SELECT id FROM user_records WHERE user_id = ? AND record = ?', (user_id, record))
        if not cursor.fetchone():
            cursor.execute('INSERT INTO user_records (user_id, record) VALUES (?, ?)', (user_id, record))
    conn.commit()
    conn.close()

def format_url(raw_host):
    host = raw_host.strip()
    if not host.startswith("http://") and not host.startswith("https://"):
        host = "https://" + host
    return host.rstrip('/')

def fetch_data_via_api(server):
    url = format_url(server['host'])
    user = server['user']
    pwd = server['password']
    xray_cfg = server['xray_config']

    with XrayTunnelContext(xray_cfg) as proxy_url:
        proxies = None
        if proxy_url:
            proxies = {"http": proxy_url, "https": proxy_url}

        try:
            session = requests.Session()
            session.verify = False

            login_resp = session.post(f"{url}/login", data={"username": user, "password": pwd}, proxies=proxies, timeout=15)
            if not login_resp.json().get("success"): return None

            sub_domain, sub_port, sub_path = "", "", "/sub/"
            try:
                set_resp = session.post(f"{url}/panel/setting/all", proxies=proxies, timeout=10)
                if set_resp.status_code == 404:
                    set_resp = session.get(f"{url}/panel/setting/all", proxies=proxies, timeout=10)
                sub_settings = set_resp.json().get("obj", {})
                sub_domain = sub_settings.get("subDomain", "")
                sub_port = sub_settings.get("subPort", "")
                sub_path = sub_settings.get("subPath", "/sub/")
            except: pass

            inb_resp = session.get(f"{url}/panel/api/inbounds/list", proxies=proxies, timeout=15)
            inbounds = inb_resp.json().get("obj", [])

            traffics = []
            for ib in inbounds:
                client_stats = ib.get('clientStats', [])
                try: settings = json.loads(ib.get('settings', '{}'))
                except: settings = {}
                clients = settings.get('clients', [])

                email_map = {}
                for c in clients:
                    em = c.get('email')
                    if em: email_map[em] = {'id': c.get('id'), 'subId': c.get('subId')}

                for stat in client_stats:
                    em = stat.get('email')
                    if not em or em not in email_map: continue
                    traffics.append({
                        'email': em,
                        'up': int(stat.get('up', 0)),
                        'down': int(stat.get('down', 0)),
                        'expiry': int(stat.get('expiryTime', 0)),
                        'total': int(stat.get('total', 0)),
                        'uuid': email_map[em]['id'],
                        'subId': email_map[em]['subId']
                    })

            online_c = 0
            try:
                onlines_resp = session.post(f"{url}/panel/api/inbounds/onlines", proxies=proxies, timeout=10)
                if onlines_resp.status_code == 404:
                    onlines_resp = session.get(f"{url}/panel/api/inbounds/onlines", proxies=proxies, timeout=10)
                
                if onlines_resp.status_code == 200:
                    onlines_data = onlines_resp.json()
                    if isinstance(onlines_data.get("obj"), list):
                        online_c = len(onlines_data.get("obj"))
            except: pass

            return {
                "traffics": traffics,
                "online_count": online_c,
                "sub_domain": sub_domain,
                "sub_port": sub_port,
                "sub_path": sub_path
            }
        except Exception as e:
            return None

def check_subscriptions_bg():
    global server_states
    while True:
        try:
            # خواندن سریع لیست سرورها و بستن فوری دیتابیس برای جلوگیری از قفل شدن
            conn = get_db()
            c = conn.cursor()
            c.execute("SELECT * FROM servers")
            servers = [dict(row) for row in c.fetchall()]
            conn.close()
            
            messages_to_send = []
            
            for srv in servers:
                srv_id = srv['id']
                srv_name = srv['name'] if srv['name'] else srv['host']
                
                if srv_id not in server_states:
                    server_states[srv_id] = {"status": "unknown", "online": -1}
                    
                # عملیات کند شبکه بیرون از اتصال دیتابیس انجام میشود
                api_data = fetch_data_via_api(srv)
                
                if not api_data:
                    if server_states[srv_id]["status"] != "offline":
                        server_states[srv_id]["status"] = "offline"
                        send_admin_alert(f"⚠️ هشدار: ارتباط ربات با سرور [{srv_name}] قطع شد!")
                    continue
                    
                if server_states[srv_id]["status"] == "offline":
                    server_states[srv_id]["status"] = "online"
                    send_admin_alert(f"✅ وضعیت: ارتباط با سرور [{srv_name}] مجدداً برقرار شد.")
                else:
                    server_states[srv_id]["status"] = "online"
                    
                current_online = api_data['online_count']
                if current_online == 0 and server_states[srv_id]["online"] > 0:
                    send_admin_alert(f"📉 توجه: تعداد کاربران آنلاین سرور [{srv_name}] به صفر رسید.")
                server_states[srv_id]["online"] = current_online
                
                # باز کردن مجدد دیتابیس فقط برای ثبت سریع اطلاعات همین یک سرور
                conn = get_db()
                c = conn.cursor()
                
                c.execute("UPDATE servers SET online_count = ? WHERE id = ?", (current_online, srv_id))
                
                for t in api_data['traffics']:
                    email = t['email']
                    up = t['up']
                    down = t['down']
                    expiry = t['expiry']
                    total = t['total']
                    target_uuid = t['uuid']
                    used = up + down
                    
                    c.execute('INSERT OR REPLACE INTO client_live_stats (uuid, email, server_host, total, used, expiry) VALUES (?, ?, ?, ?, ?, ?)',
                              (target_uuid, email, srv['host'], total, used, expiry))
                    
                    c.execute('SELECT uuid, user_id, original_config FROM uuid_user_map WHERE email = ? AND server_host = ?', (email, srv['host']))
                    map_info = c.fetchone()
                    if not map_info: continue
                    uuid_val, user_id, config = map_info
                    
                    rem = total - used
                    now = int(time.time() * 1000)
                    
                    c.execute("SELECT notified_2gb, notified_24h, is_dead, last_total, last_expiry, last_used FROM account_states_v2 WHERE uuid = ?", (uuid_val,))
                    state = c.fetchone()
                    if not state:
                        c.execute("INSERT INTO account_states_v2 (uuid, last_total, last_expiry, last_used) VALUES (?, ?, ?, ?)", (uuid_val, total, expiry, used))
                        n_2gb, n_24h, is_dead, last_tot, last_exp, last_used = 0, 0, 0, total, expiry, used
                    else:
                        n_2gb, n_24h, is_dead, last_tot, last_exp, last_used = state
                        
                    if total != last_tot or expiry != last_exp or used < last_used:
                        n_2gb, n_24h, is_dead = 0, 0, 0
                        
                    t_left = expiry - now if expiry > 0 else 999999999999
                    
                    if (total > 0 and rem <= 0) or (expiry > 0 and t_left <= 0):
                        if is_dead == 0:
                            if total > 0 and rem <= 0:
                                msg = f"❌ مشترک گرامی، حجم اشتراک شما کاملاً به پایان رسیده است.\n\n{config}\n\n💎 جهت تمدید سرویس و دریافت اشتراک جدید، لطفاً با پشتیبانی در ارتباط باشید:\n👨‍💻 @topspeedvpn_admin"
                            else:
                                msg = f"❌ مشترک گرامی، زمان اشتراک شما به پایان رسیده است.\n\n{config}\n\n💎 جهت تمدید سرویس و دریافت اشتراک جدید، لطفاً با پشتیبانی در ارتباط باشید:\n👨‍💻 @topspeedvpn_admin"
                            messages_to_send.append((user_id, msg))
                            is_dead = 1
                    elif is_dead == 0:
                        if total > 0 and rem < (2*1024**3) and n_2gb == 0:
                            msg = f"⚠️ کاربر عزیز، حجم سرویس شما رو به اتمام است.\n\n{config}\n📊 حجم باقیمانده: {rem/(1024**3):.2f} گیگابایت\n\n💎 جهت جلوگیری از قطعی، لطفاً برای تمدید اقدام نمایید:\n👨‍💻 @topspeedvpn_admin"
                            messages_to_send.append((user_id, msg))
                            n_2gb = 1
                        if expiry > 0 and t_left < (24*3600*1000) and n_24h == 0:
                            msg = f"⏰ کاربر عزیز، زمان سرویس شما رو به اتمام است.\n\n{config}\n📅 زمان باقیمانده: {t_left/(1000*3600):.1f} ساعت\n\n💎 جهت جلوگیری از قطعی، لطفاً برای تمدید اقدام نمایید:\n👨‍💻 @topspeedvpn_admin"
                            messages_to_send.append((user_id, msg))
                            n_24h = 1
                            
                    c.execute("UPDATE account_states_v2 SET notified_2gb=?, notified_24h=?, is_dead=?, last_total=?, last_expiry=?, last_used=? WHERE uuid=?", 
                              (n_2gb, n_24h, is_dead, total, expiry, used, uuid_val))
                              
                conn.commit()
                conn.close()
            
            # بخش سریع بررسی و ذخیره پیام های همگانی
            conn = get_db()
            c = conn.cursor()
            c.execute("SELECT id, message, target_server FROM broadcast_queue WHERE status = 'pending'")
            pending_bc = c.fetchall()
            for bc in pending_bc:
                bc_id, bc_text, target_srv = bc
                if target_srv == 'all':
                    c.execute("SELECT DISTINCT user_id FROM uuid_user_map")
                else:
                    c.execute("SELECT DISTINCT user_id FROM uuid_user_map WHERE server_host = ?", (target_srv,))
                all_users = c.fetchall()
                for u in all_users:
                    messages_to_send.append((u[0], bc_text))
                c.execute("UPDATE broadcast_queue SET status = 'sent' WHERE id = ?", (bc_id,))
            conn.commit()
            conn.close()
            
            # ارسال پیام ها به تلگرام (در حالی که دیتابیس بسته است تا ربات کند نشود)
            for uid, msg in messages_to_send:
                try: 
                    bot.send_message(uid, msg)
                    time.sleep(0.05) # جلوگیری از اسپم شدن توسط تلگرام
                except: 
                    pass
                
        except Exception as e:
            pass
        time.sleep(CHECK_INTERVAL_SECONDS)

threading.Thread(target=check_subscriptions_bg, daemon=True).start()

@bot.message_handler(commands=['start'])
def handle_cmds(msg):
    save_user(msg.chat.id, msg.from_user.username)
    not_mem = check_membership(msg.chat.id)
    if not_mem:
        markup = types.InlineKeyboardMarkup(row_width=1)
        for ch in not_mem: markup.add(types.InlineKeyboardButton(f"عضویت در {ch}", url=f"https://t.me/{ch[1:]}"))
        markup.add(types.InlineKeyboardButton("✅ عضو شدم", callback_data="check"))
        bot.send_message(msg.chat.id, "🌹 کاربر گرامی، جهت استفاده از امکانات ربات لطفاً ابتدا در کانال‌های زیر عضو شوید:", reply_markup=markup)
    else:
        bot.send_message(msg.chat.id, "🌹 با سلام و احترام؛\nبه ربات پشتیبانی و مدیریت اشتراک خوش آمدید.\n\n👇 لطفاً از منوی زیر یکی از گزینه‌ها را انتخاب نمایید:", reply_markup=get_main_keyboard())

@bot.callback_query_handler(func=lambda c: True)
def inline_callbacks(call):
    if call.data == "check":
        if not check_membership(call.message.chat.id):
            try: bot.delete_message(call.message.chat.id, call.message.message_id)
            except: pass
            bot.send_message(call.message.chat.id, "✅ عضویت شما تایید شد.\n\n👇 لطفاً از منوی زیر گزینه مورد نظر خود را انتخاب کنید:", reply_markup=get_main_keyboard())
        else:
            bot.answer_callback_query(call.id, "❌ شما هنوز در تمامی کانال‌ها عضو نشده‌اید!", show_alert=True)
    elif call.data == "ignore":
        bot.answer_callback_query(call.id, "این یک دکمه نمایشی است 📊")

def check_status_logic(message):
    txt = message.text.strip()
    
    if is_menu_button(txt):
        try: bot.clear_step_handler_by_chat_id(message.chat.id)
        except: pass
        process_text(message)
        return
        
    match = re.search(r'vless://([a-f0-9-]{36})', txt, re.IGNORECASE)
    if not match:
        bot.reply_to(message, "❌ کاربر گرامی، متنی که ارسال کردید به عنوان کانفیگ معتبر شناسایی نشد!\n\nلطفاً دقیقاً همان کانفیگ VLESS خود را کپی کرده و ارسال نمایید، یا جهت دریافت پشتیبانی به ادمین پیام دهید:\n👨‍💻 @topspeedvpn_admin")
        bot.register_next_step_handler(message, check_status_logic)
        return
        
    uuid_val = match.group(1)
    msg_wait = bot.reply_to(message, "⏳ در حال استعلام اطلاعات لحظه‌ای از سرورها...")
    
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM servers")
    servers = [dict(row) for row in c.fetchall()]
    conn.close()
    
    if not servers:
        try: bot.delete_message(message.chat.id, msg_wait.message_id)
        except: pass
        bot.send_message(message.chat.id, "❌ در حال حاضر هیچ سروری در سیستم ثبت نشده است.")
        return
    
    found_any = False
    offline_servers_count = 0
    
    for srv in servers:
        api_data = fetch_data_via_api(srv)
        if not api_data: 
            offline_servers_count += 1
            continue
        
        target_t = next((item for item in api_data['traffics'] if item['uuid'] == uuid_val), None)
        
        if target_t:
            found_any = True
            email = target_t['email']
            
            conn_l = get_db()
            conn_l.execute('INSERT OR REPLACE INTO uuid_user_map (uuid, user_id, email, server_host, original_config) VALUES (?, ?, ?, ?, ?)', 
                           (uuid_val, message.chat.id, email, srv['host'], txt))
            conn_l.commit()
            conn_l.close()
            
            up_gb = target_t['up'] / (1024**3)
            down_gb = target_t['down'] / (1024**3)
            total_gb = target_t['total'] / (1024**3)
            used_gb = up_gb + down_gb
            rem_gb = total_gb - used_gb
            now = int(time.time() * 1000)
            
            markup = types.InlineKeyboardMarkup(row_width=2)
            markup.add(types.InlineKeyboardButton(f"👤 نام اشتراک: {email}", callback_data="ignore"))
            markup.add(
                types.InlineKeyboardButton(f"📦 حجم کل: {total_gb:.2f} GB", callback_data="ignore"),
                types.InlineKeyboardButton(f"📉 باقیمانده: {rem_gb:.2f} GB", callback_data="ignore")
            )
            markup.add(
                types.InlineKeyboardButton(f"⬆️ آپلود: {up_gb:.2f} GB", callback_data="ignore"),
                types.InlineKeyboardButton(f"⬇️ دانلود: {down_gb:.2f} GB", callback_data="ignore")
            )
            
            if target_t['expiry'] == 0:
                exp_str = "♾ نامحدود"
            else:
                t_left = target_t['expiry'] - now
                if t_left <= 0:
                    exp_str = "❌ منقضی شده"
                else:
                    days = t_left / (24*3600*1000)
                    exp_str = f"⏳ {days:.1f} روز"
                    
            markup.add(types.InlineKeyboardButton(f"📅 زمان اعتبار: {exp_str}", callback_data="ignore"))
            
            bot.send_message(message.chat.id, "✅ وضعیت اشتراک شما با موفقیت استعلام شد:", reply_markup=markup)
            break
            
    try: bot.delete_message(message.chat.id, msg_wait.message_id)
    except: pass

    if not found_any:
        err_msg = "❌ کاربر گرامی، متأسفانه اطلاعات اشتراک شما در سیستم یافت نشد.\n\nلطفاً از صحت کانفیگ خود اطمینان حاصل کرده و مجدداً تلاش نمایید."
        if offline_servers_count > 0:
            err_msg += f"\n\n⚠️ ضمناً ارتباط ربات با {offline_servers_count} سرور قطع می‌باشد و امکان جستجو در آنها وجود نداشت."
        bot.send_message(message.chat.id, err_msg)

def process_cfg_step(msg):
    txt = msg.text.strip()
    
    if is_menu_button(txt):
        try: bot.clear_step_handler_by_chat_id(msg.chat.id)
        except: pass
        process_text(msg)
        return
        
    match = re.search(r'vless://([a-f0-9-]{36})', txt, re.IGNORECASE)
    if not match: 
        bot.reply_to(msg, "❌ کاربر گرامی، متنی که ارسال کردید به عنوان کانفیگ معتبر شناسایی نشد!\n\nلطفاً دقیقاً همان کانفیگ VLESS خود را کپی کرده و ارسال نمایید، یا جهت دریافت پشتیبانی به ادمین پیام دهید:\n👨‍💻 @topspeedvpn_admin")
        bot.register_next_step_handler(msg, process_cfg_step)
        return
    
    uuid_val = match.group(1)
    record = re.search(r'(v\d+)', txt)
    save_user(msg.chat.id, msg.from_user.username, record.group(1) if record else None)
    
    msg_wait = bot.send_message(msg.chat.id, "⏳ در حال ساخت لینک سابسکریپشن اختصاصی شما...")
    
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM servers")
    servers = [dict(row) for row in c.fetchall()]
    conn.close()
    
    if not servers:
        try: bot.delete_message(msg.chat.id, msg_wait.message_id)
        except: pass
        bot.send_message(msg.chat.id, "❌ در حال حاضر هیچ سروری در سیستم ثبت نشده است.")
        return
    
    url = None
    offline_servers_count = 0
    
    for srv in servers:
        api_data = fetch_data_via_api(srv)
        if not api_data: 
            offline_servers_count += 1
            continue
        
        target_t = next((item for item in api_data['traffics'] if item['uuid'] == uuid_val), None)
        
        if target_t:
            sub_id = target_t['subId']
            email = target_t['email']
            
            conn_l = get_db()
            conn_l.execute('INSERT OR REPLACE INTO uuid_user_map (uuid, user_id, email, server_host, original_config) VALUES (?, ?, ?, ?, ?)', 
                           (uuid_val, msg.chat.id, email, srv['host'], txt))
            conn_l.commit()
            conn_l.close()
            
            sub_domain = api_data['sub_domain'] or urlparse(format_url(srv['host'])).hostname
            sub_port = api_data['sub_port']
            sub_path = api_data['sub_path']
            
            port_str = "" if str(sub_port) in ["80", "443", ""] else f":{sub_port}"
            if not sub_path.startswith('/'): sub_path = '/' + sub_path
            if not sub_path.endswith('/'): sub_path = sub_path + '/'
            
            url = f"http://{sub_domain}{port_str}{sub_path}{sub_id}"
            break
            
    try: bot.delete_message(msg.chat.id, msg_wait.message_id)
    except: pass
    
    if url:
        bot.reply_to(msg, f"🔗 لینک سابسکریپشن شما آماده است:\n\n{url}")
    else:
        err_msg = "❌ کاربر گرامی، متأسفانه سابسکریپشنی برای این کانفیگ یافت نشد.\n\nلطفاً بررسی کنید که کانفیگ صحیح را ارسال کرده باشید."
        if offline_servers_count > 0:
            err_msg += f"\n\n⚠️ ضمناً ارتباط ربات با {offline_servers_count} سرور قطع می‌باشد و امکان جستجو در آنها وجود نداشت."
        bot.reply_to(msg, err_msg)

@bot.message_handler(func=lambda m: True)
def process_text(msg):
    uid, txt = msg.chat.id, msg.text.strip()
    if check_membership(uid): return handle_cmds(msg)
    
    try: bot.clear_step_handler_by_chat_id(uid)
    except: pass
    
    if "استارت" in txt or "/start" in txt:
        handle_cmds(msg)
    elif "دریافت" in txt:
        bot.send_message(uid, "🌹 مشترک گرامی، لطفاً کانفیگ (VLESS) خود را جهت دریافت لینک سابسکرایبشن ارسال نمایید:", reply_markup=get_main_keyboard())
        bot.register_next_step_handler(msg, process_cfg_step)
    elif "استعلام" in txt:
        bot.send_message(uid, "📊 مشترک گرامی، لطفاً کانفیگ خود را جهت استعلام دقیق حجم و زمان ارسال نمایید:", reply_markup=get_main_keyboard())
        bot.register_next_step_handler(msg, check_status_logic)
    else:
        if "vless://" in txt.lower():
            process_cfg_step(msg)
        else:
            bot.send_message(uid, "👇 لطفاً از گزینه‌های منوی زیر استفاده نمایید:", reply_markup=get_main_keyboard())

print("🤖 Xray API Telebot started successfully!")
bot.infinity_polling()
EOF

# --- main.py ---
cat << 'EOF' > main.py
import os
import shutil
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.responses import HTMLResponse, FileResponse
from pydantic import BaseModel
from typing import Optional, List
import sqlite3
import uvicorn
import datetime
import time
import requests
import urllib3
import json

urllib3.disable_warnings()

app = FastAPI(title="Smart Proxy Panel")
DB_PATH = 'users.db'

def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('CREATE TABLE IF NOT EXISTS users (user_id INTEGER PRIMARY KEY, username TEXT)')
    c.execute('CREATE TABLE IF NOT EXISTS user_records (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, record TEXT)')
    c.execute('CREATE TABLE IF NOT EXISTS uuid_user_map (uuid TEXT, user_id INTEGER, email TEXT, server_host TEXT, original_config TEXT, PRIMARY KEY (uuid, server_host))')
    c.execute('CREATE TABLE IF NOT EXISTS account_states_v2 (uuid TEXT PRIMARY KEY, notified_2gb INTEGER, notified_24h INTEGER, is_dead INTEGER, last_total INTEGER, last_expiry INTEGER, last_used INTEGER)')
    c.execute('CREATE TABLE IF NOT EXISTS client_live_stats (uuid TEXT PRIMARY KEY, email TEXT, server_host TEXT, total INTEGER, used INTEGER, expiry INTEGER, is_active INTEGER DEFAULT 1)')
    c.execute('CREATE TABLE IF NOT EXISTS servers (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, host TEXT, user TEXT, password TEXT, xray_config TEXT, online_count INTEGER DEFAULT 0)')
    c.execute('CREATE TABLE IF NOT EXISTS broadcast_queue (id INTEGER PRIMARY KEY AUTOINCREMENT, message TEXT, target_server TEXT, status TEXT DEFAULT "pending", created_at DATETIME DEFAULT CURRENT_TIMESTAMP)')
    c.execute('CREATE TABLE IF NOT EXISTS admin (id INTEGER PRIMARY KEY, username TEXT, password TEXT)')
    c.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)')
    
    c.execute('SELECT count(*) FROM admin')
    if c.fetchone()[0] == 0: c.execute("INSERT INTO admin (username, password) VALUES ('ADMIN_PLACEHOLDER', 'PASS_PLACEHOLDER')")
    conn.commit(); conn.close()

init_db()

def get_db():
    conn = sqlite3.connect(DB_PATH, timeout=20)
    conn.row_factory = sqlite3.Row
    return conn

class ServerModel(BaseModel): name: str; host: str; user: str; password: str; xray_config: Optional[str] = ""
class BroadcastModel(BaseModel): message: str; target_server: str
class LoginModel(BaseModel): username: str; password: str
class SettingsModel(BaseModel): admin_bot_token: str; admin_chat_id: str

@app.post("/api/login")
def login(data: LoginModel):
    conn = get_db(); c = conn.cursor()
    c.execute("SELECT * FROM admin WHERE username=? AND password=?", (data.username, data.password))
    admin = c.fetchone(); conn.close()
    if admin: return {"success": True}
    return {"success": False}

@app.get("/api/dashboard")
def get_dashboard():
    conn = get_db(); c = conn.cursor()
    c.execute("SELECT COUNT(DISTINCT user_id) FROM uuid_user_map")
    total_users = c.fetchone()[0]
    
    c.execute("SELECT COUNT(*) FROM servers")
    total_servers = c.fetchone()[0]
    
    c.execute("SELECT SUM(online_count) FROM servers")
    sum_res = c.fetchone()[0]
    total_online = int(sum_res) if sum_res else 0
    
    c.execute("""
        SELECT COALESCE(s.name, u.server_host) as record, COUNT(DISTINCT u.user_id) as count 
        FROM uuid_user_map u 
        LEFT JOIN servers s ON u.server_host = s.host 
        GROUP BY u.server_host
    """)
    user_stats = [dict(row) for row in c.fetchall()]
    
    now_ms = int(time.time() * 1000)
    limit_24h = now_ms + (24 * 3600 * 1000)
    c.execute("SELECT email, uuid, expiry, server_host FROM client_live_stats WHERE expiry > 0 AND expiry <= ? AND expiry > ? ORDER BY expiry ASC", (limit_24h, now_ms))
    expiring_soon = [dict(row) for row in c.fetchall()]
    conn.close()
    
    return {
        "total_users": total_users,
        "total_servers": total_servers,
        "total_online": total_online,
        "user_stats": user_stats,
        "expiring_soon": expiring_soon,
        "now": now_ms
    }

@app.get("/api/expired_48h")
def get_expired_48h():
    conn = get_db()
    now_ms = int(time.time() * 1000)
    limit_time = now_ms - (48 * 3600 * 1000)
    c = conn.cursor()
    c.execute("SELECT uuid, email, server_host, expiry FROM client_live_stats WHERE expiry > 0 AND expiry < ?", (limit_time,))
    results = [dict(row) for row in c.fetchall()]
    conn.close()
    return results

@app.delete("/api/expired_48h")
def delete_expired_48h():
    conn = get_db()
    now_ms = int(time.time() * 1000)
    limit_time = now_ms - (48 * 3600 * 1000)
    c = conn.cursor()
    c.execute("SELECT uuid, email, server_host, expiry FROM client_live_stats WHERE expiry > 0 AND expiry < ?", (limit_time,))
    clients_to_delete = c.fetchall()

    servers_to_clean = {}
    for client in clients_to_delete:
        sh = client['server_host']
        if sh not in servers_to_clean: servers_to_clean[sh] = []
        servers_to_clean[sh].append(client)

    c.execute("SELECT * FROM servers")
    servers = {s['name']: dict(s) for s in c.fetchall()}

    deleted_count = 0

    for sh, clients in servers_to_clean.items():
        srv = servers.get(sh)
        if not srv: continue

        url = srv['host'].rstrip('/')
        if not url.startswith("http"): url = "https://" + url

        session = requests.Session()
        session.verify = False
        try:
            login_res = session.post(f"{url}/login", data={"username": srv['user'], "password": srv['password']}, timeout=10)
            if not login_res.json().get("success"): continue

            inb_res = session.get(f"{url}/panel/api/inbounds/list", timeout=10)
            inbounds = inb_res.json().get("obj", [])

            uuid_to_inbound = {}
            for ib in inbounds:
                try:
                    settings = json.loads(ib.get('settings', '{}'))
                    for cl in settings.get('clients', []):
                        uuid_to_inbound[cl['id']] = ib['id']
                except: pass

            for cl in clients:
                uid = cl['uuid']
                inb_id = uuid_to_inbound.get(uid)
                if inb_id is not None:
                    del_res = session.post(f"{url}/panel/api/inbounds/{inb_id}/delClient/{uid}", timeout=10)
                    if del_res.json().get("success"):
                        c.execute("DELETE FROM client_live_stats WHERE uuid=?", (uid,))
                        c.execute("DELETE FROM uuid_user_map WHERE uuid=?", (uid,))
                        deleted_count += 1
        except: pass

    conn.commit()
    conn.close()
    return {"status": "success", "deleted": deleted_count}

@app.get("/api/servers")
def get_servers():
    conn = get_db(); c = conn.cursor()
    c.execute("SELECT * FROM servers ORDER BY id DESC")
    servers = [dict(row) for row in c.fetchall()]; conn.close()
    return servers

@app.post("/api/servers")
def add_server(server: ServerModel):
    conn = get_db(); c = conn.cursor()
    c.execute("INSERT INTO servers (name, host, user, password, xray_config, online_count) VALUES (?, ?, ?, ?, ?, 0)", 
              (server.name, server.host, server.user, server.password, server.xray_config))
    conn.commit(); conn.close()
    return {"status": "success"}

@app.put("/api/servers/{server_id}")
def update_server(server_id: int, server: ServerModel):
    conn = get_db(); c = conn.cursor()
    c.execute("UPDATE servers SET name=?, host=?, user=?, password=?, xray_config=? WHERE id=?", 
              (server.name, server.host, server.user, server.password, server.xray_config, server_id))
    conn.commit(); conn.close()
    return {"status": "success"}

@app.delete("/api/servers/{server_id}")
def delete_server(server_id: int):
    conn = get_db(); c = conn.cursor()
    c.execute("DELETE FROM servers WHERE id=?", (server_id,))
    conn.commit(); conn.close()
    return {"status": "success"}

@app.post("/api/broadcast")
def add_broadcast(data: BroadcastModel):
    conn = get_db(); c = conn.cursor()
    c.execute("INSERT INTO broadcast_queue (message, target_server) VALUES (?, ?)", (data.message, data.target_server))
    conn.commit(); conn.close()
    return {"status": "success"}

@app.get("/api/settings")
def get_settings():
    conn = get_db(); c = conn.cursor()
    c.execute("SELECT key, value FROM settings")
    rows = c.fetchall(); conn.close()
    settings = {row['key']: row['value'] for row in rows}
    return {
        "admin_bot_token": settings.get("admin_bot_token", ""),
        "admin_chat_id": settings.get("admin_chat_id", "")
    }

@app.post("/api/settings")
def save_settings(data: SettingsModel):
    conn = get_db(); c = conn.cursor()
    c.execute("INSERT OR REPLACE INTO settings (key, value) VALUES ('admin_bot_token', ?)", (data.admin_bot_token,))
    c.execute("INSERT OR REPLACE INTO settings (key, value) VALUES ('admin_chat_id', ?)", (data.admin_chat_id,))
    conn.commit(); conn.close()
    return {"status": "success"}

@app.get("/api/backup")
def backup_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute('PRAGMA wal_checkpoint(TRUNCATE);')
    conn.commit()
    conn.close()
    filename = f"backup_{datetime.datetime.now().strftime('%Y%m%d_%H%M')}.db"
    return FileResponse(DB_PATH, media_type="application/octet-stream", filename=filename)

@app.post("/api/restore")
async def restore_db(file: UploadFile = File(...)):
    if os.path.exists(DB_PATH + '-wal'):
        os.remove(DB_PATH + '-wal')
    if os.path.exists(DB_PATH + '-shm'):
        os.remove(DB_PATH + '-shm')
    with open(DB_PATH, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # اجرای اتوماتیک آپگرید برای بکاپ های قدیمی تا خطای پنل از بین برود
    init_db()
    
    return {"status": "success"}

@app.get("/", response_class=HTMLResponse)
async def serve_panel():
    with open("panel.html", "r", encoding="utf-8") as f: return f.read()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT_PLACEHOLDER)
EOF

# 7. Apply Variables dynamically
echo -e "${CYAN}[*] Applying User Configurations...${RESET}"
sed -i "s/BOT_TOKEN_PLACEHOLDER/$BOT_TOKEN/g" xray_bot.py
sed -i "s/PORT_PLACEHOLDER/$PANEL_PORT/g" main.py
sed -i "s/ADMIN_PLACEHOLDER/$PANEL_USER/g" main.py
sed -i "s/PASS_PLACEHOLDER/$PANEL_PASS/g" main.py

# 8. Python Environment (Including SOCKS proxy fix)
echo -e "${CYAN}[*] Setting up Python Environment...${RESET}"
python3 -m venv venv
source venv/bin/activate
pip install -q telebot pyTelegramBotAPI "requests[socks]" fastapi uvicorn pydantic python-multipart

# 9. Create Management Script (topspeedsub)
cat << 'EOF_MENU' > /usr/bin/topspeedsub
#!/bin/bash
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
RESET="\e[0m"

change_token() {
    read -p "Enter New Bot Token: " new_token
    sed -i "s/BOT_TOKEN = \".*\"/BOT_TOKEN = \"$new_token\"/g" /root/Smart-Panel/xray_bot.py
    systemctl restart topspeed-bot
    echo -e "${GREEN}[+] Bot token updated successfully!${RESET}"
    sleep 2
}

change_port() {
    read -p "Enter New Panel Port: " new_port
    sed -i "s/port=[0-9]*/port=$new_port/g" /root/Smart-Panel/main.py
    systemctl restart topspeed-panel
    echo -e "${GREEN}[+] Panel port updated to $new_port successfully!${RESET}"
    sleep 2
}

change_creds() {
    read -p "Enter New Admin Username: " new_user
    read -p "Enter New Admin Password: " new_pass
    sqlite3 /root/Smart-Panel/users.db "UPDATE admin SET username='$new_user', password='$new_pass';"
    echo -e "${GREEN}[+] Admin credentials updated successfully!${RESET}"
    sleep 2
}

uninstall_all() {
    echo -e "${RED}[!] WARNING: This will delete everything (including users database).${RESET}"
    read -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        systemctl stop topspeed-panel topspeed-bot
        systemctl disable topspeed-panel topspeed-bot
        rm -f /etc/systemd/system/topspeed-*
        systemctl daemon-reload
        rm -rf /root/Smart-Panel
        rm -f /usr/bin/topspeedsub
        echo -e "${GREEN}[+] TopSpeedSub completely uninstalled.${RESET}"
        exit 0
    fi
}

while true; do
    clear
    echo -e "${CYAN}====================================================${RESET}"
    echo -e "${GREEN}             TopSpeed Panel Management              ${RESET}"
    echo -e "${CYAN}====================================================${RESET}"
    echo -e "1. ${YELLOW}Change Telegram Bot Token${RESET}"
    echo -e "2. ${YELLOW}Change Panel Web Port${RESET}"
    echo -e "3. ${YELLOW}Change Panel Username & Password${RESET}"
    echo -e "4. ${YELLOW}Restart Services${RESET}"
    echo -e "5. ${RED}Uninstall Entire System${RESET}"
    echo -e "6. Exit"
    echo -e "${CYAN}====================================================${RESET}"
    read -p "Select an option [1-6]: " choice
    case $choice in
        1) change_token ;;
        2) change_port ;;
        3) change_creds ;;
        4) systemctl restart topspeed-panel topspeed-bot && echo -e "${GREEN}[+] Services Restarted!${RESET}" && sleep 2 ;;
        5) uninstall_all ;;
        6) exit 0 ;;
        *) echo -e "${RED}Invalid option!${RESET}" && sleep 1 ;;
    esac
done
EOF_MENU
chmod +x /usr/bin/topspeedsub

# 10. Create Systemd Services
echo -e "${CYAN}[*] Creating System Services...${RESET}"
cat << 'EOF_SERVICE' > /etc/systemd/system/topspeed-panel.service
[Unit]
Description=TopSpeed Smart Panel Web
After=network.target

[Service]
WorkingDirectory=/root/Smart-Panel
ExecStart=/root/Smart-Panel/venv/bin/python /root/Smart-Panel/main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF_SERVICE

cat << 'EOF_SERVICE' > /etc/systemd/system/topspeed-bot.service
[Unit]
Description=TopSpeed Telegram Bot
After=network.target

[Service]
WorkingDirectory=/root/Smart-Panel
ExecStart=/root/Smart-Panel/venv/bin/python /root/Smart-Panel/xray_bot.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF_SERVICE

systemctl daemon-reload
systemctl enable topspeed-panel topspeed-bot > /dev/null 2>&1
systemctl restart topspeed-panel topspeed-bot

# Force getting IPv4 address
IPV4=$(curl -4 -s icanhazip.com || curl -s -4 ifconfig.me)

echo ""
echo -e "${GREEN}====================================================${RESET}"
echo -e "${GREEN}   Installation Completed Successfully!             ${RESET}"
echo -e "${CYAN}====================================================${RESET}"
echo -e "${YELLOW}[+] Panel Address :${RESET} http://$IPV4:$PANEL_PORT"
echo -e "${YELLOW}[+] Admin Username:${RESET} $PANEL_USER"
echo -e "${YELLOW}[+] Admin Password:${RESET} $PANEL_PASS"
echo -e "${CYAN}====================================================${RESET}"
echo -e "Type ${GREEN}topspeedsub${RESET} anywhere in terminal to open the management menu."
echo ""
