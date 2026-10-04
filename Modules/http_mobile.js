let TOKEN = null;
let autoLogTimer = null;
let metricsAutoTimer = null;
let allApps = [];
let allPkgs = [];
let appsFilter = 'all';
let pkgsFilter = 'all';
let currentFilePath = '/sdcard/';
let holdTimers = {};
let holdIntervals = {};

(function init() {
    const params = new URLSearchParams(window.location.search);
    TOKEN = params.get('token');

    if (!TOKEN) {
        document.getElementById('infoContent').innerHTML =
            'Токен не указан в URL.<br><br>Откройте страницу по ссылке с <b>?token=XXXX</b>.';
        return;
    }

    document.getElementById('tokenInfo').textContent = 'Токен: ' + TOKEN;

    updateStatus();
    loadApps();
    loadInfo();
    initHoldButtons();
    initApkUpload();

    setInterval(updateStatus, 5000);
})();

/* ================= ХЕЛПЕРЫ ================= */
async function apiFetch(path, options = {}) {
    if (!TOKEN) throw new Error('No token');
    const sep = path.includes('?') ? '&' : '?';
    const url = path + sep + 'token=' + encodeURIComponent(TOKEN);
    const opts = {
        ...options,
        headers: {
            'Content-Type': 'application/json',
            'X-Token': TOKEN,
            ...(options.headers || {})
        }
    };
    const resp = await fetch(url, opts);
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    return await resp.json();
}

function esc(s) {
    return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function escJs(s) {
    return String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

function fmtSize(b) {
    if (b < 1024) return b + ' Б';
    if (b < 1024 * 1024) return (b / 1024).toFixed(1) + ' КБ';
    if (b < 1024 * 1024 * 1024) return (b / 1024 / 1024).toFixed(1) + ' МБ';
    return (b / 1024 / 1024 / 1024).toFixed(2) + ' ГБ';
}

function showToast(msg, type = '') {
    const t = document.getElementById('toast');
    t.textContent = msg;
    t.className = 'toast show ' + type;
    clearTimeout(t._timer);
    t._timer = setTimeout(() => { t.className = 'toast ' + type; }, 2500);
}

function openModal(src) {
    document.getElementById('modalImg').src = src;
    document.getElementById('modal').classList.add('show');
}
function closeModal() {
    document.getElementById('modal').classList.remove('show');
}

/* ================= ВКЛАДКИ ================= */
document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById('panel-' + tab.dataset.tab).classList.add('active');

        const t = tab.dataset.tab;
        if (t === 'packages' && allPkgs.length === 0) loadPackages();
        if (t === 'windows') { loadCurrentActivity(); loadWindows(); }
        if (t === 'files') loadFiles();
        if (t === 'shots') loadShots();
        if (t === 'metrics') loadMetrics();
        if (t === 'presets') loadPresetsState();
        if (t === 'bt') loadBluetooth();
        if (t === 'wifi') loadWifi();
    });
});

/* ================= УДЕРЖАНИЕ КНОПОК ================= */
function initHoldButtons() {
    document.querySelectorAll('[data-hold]').forEach(btn => {
        const key = btn.dataset.hold;

        const start = (e) => {
            e.preventDefault();
            btn.classList.add('holding');

            // Первое нажатие — сразу
            sendKey(key);

            // Через 500 мс — начинаем повторять
            holdTimers[key] = setTimeout(() => {
                holdIntervals[key] = setInterval(() => {
                    sendKey(key);
                }, 250);
            }, 500);
        };

        const stop = () => {
            btn.classList.remove('holding');
            if (holdTimers[key]) {
                clearTimeout(holdTimers[key]);
                holdTimers[key] = null;
            }
            if (holdIntervals[key]) {
                clearInterval(holdIntervals[key]);
                holdIntervals[key] = null;
            }
        };

        btn.addEventListener('mousedown', start);
        btn.addEventListener('touchstart', start, { passive: false });
        btn.addEventListener('mouseup', stop);
        btn.addEventListener('mouseleave', stop);
        btn.addEventListener('touchend', stop);
        btn.addEventListener('touchcancel', stop);
    });
}

/* ================= СТАТУС ================= */
async function updateStatus() {
    try {
        const data = await apiFetch('/api/status');
        const dot = document.getElementById('statusDot');
        const txt = document.getElementById('statusText');
        if (data.connected) {
            dot.className = 'status-dot on';
            txt.textContent = data.deviceIp || 'OK';
        } else {
            dot.className = 'status-dot off';
            txt.textContent = 'Offline';
        }
    } catch (e) {
        document.getElementById('statusDot').className = 'status-dot off';
        document.getElementById('statusText').textContent = 'Err';
    }
}

/* ================= ПУЛЬТ ================= */
async function sendKey(key) {
    try {
        const data = await apiFetch('/api/remote/key', {
            method: 'POST',
            body: JSON.stringify({ key })
        });
        if (!data.success) showToast('Ошибка', 'err');
    } catch (e) {
        showToast('Ошибка: ' + e.message, 'err');
    }
}

async function sendText() {
    const input = document.getElementById('textInput');
    const text = input.value;
    if (!text) { showToast('Введите текст', 'err'); return; }
    try {
        const data = await apiFetch('/api/remote/text', {
            method: 'POST',
            body: JSON.stringify({ text })
        });
        if (data.success) {
            showToast(data.warning || 'Отправлено', 'ok');
            input.value = '';
        } else {
            showToast(data.message || data.error || 'Ошибка', 'err');
        }
    } catch (e) {
        showToast('Ошибка: ' + e.message, 'err');
    }
}

/* ================= ЗАПУСК ПРИЛОЖЕНИЙ ================= */
function setAppsFilter(f) {
    appsFilter = f;
    document.querySelectorAll('[data-filter]').forEach(b => {
        b.classList.toggle('active', b.dataset.filter === f);
    });
    renderApps();
}

async function loadApps() {
    const list = document.getElementById('appsList');
    list.innerHTML = '<div style="text-align:center;padding:20px;color:#a0a0a0;">Загрузка...</div>';
    try {
        const data = await apiFetch('/api/apps');
        allApps = data.apps || [];
        renderApps();
    } catch (e) {
        list.innerHTML = '<div style="color:#ff9090;padding:20px;">Ошибка: ' + e.message + '</div>';
    }
}

function renderApps() {
    const list = document.getElementById('appsList');
    const q = (document.getElementById('appsSearch').value || '').toLowerCase();

    let filtered = allApps.filter(a => !q || a.package.toLowerCase().includes(q));
    if (appsFilter === 'user')   filtered = filtered.filter(a => !a.isSystem);
    if (appsFilter === 'system') filtered = filtered.filter(a => a.isSystem);

    if (filtered.length === 0) {
        list.innerHTML = '<div style="text-align:center;padding:20px;color:#a0a0a0;">Ничего не найдено</div>';
        return;
    }

    filtered.sort((a, b) => {
        if (a.isSystem !== b.isSystem) return a.isSystem ? 1 : -1;
        return a.package.localeCompare(b.package);
    });

    const shown = filtered.slice(0, 300);
    list.innerHTML = shown.map(a => `
        <div class="app-item">
            <div class="info">
                <div class="pkg ${a.isSystem ? 'sys' : 'usr'}">
                    ${a.isSystem ? '[SYS] ' : '[USR] '}${esc(a.package)}
                </div>
            </div>
            <div class="actions">
                <button onclick="launchApp('${escJs(a.package)}')">▶</button>
            </div>
        </div>
    `).join('');

    if (filtered.length > 300) {
        list.innerHTML += `<div style="text-align:center;padding:10px;color:#a0a0a0;font-size:11px;">... и ещё ${filtered.length - 300}</div>`;
    }
}

async function launchApp(pkg) {
    try {
        const data = await apiFetch('/api/apps/launch', {
            method: 'POST',
            body: JSON.stringify({ package: pkg })
        });
        showToast(data.success ? 'Запущено' : 'Ошибка', data.success ? 'ok' : 'err');
    } catch (e) {
        showToast('Ошибка: ' + e.message, 'err');
    }
}

/* ================= ПАКЕТЫ ================= */
function setPkgsFilter(f) {
    pkgsFilter = f;
    document.querySelectorAll('[data-pfilter]').forEach(b => {
        b.classList.toggle('active', b.dataset.pfilter === f);
    });
    renderPkgs();
}

async function loadPackages() {
    const list = document.getElementById('pkgsList');
    list.innerHTML = '<div style="text-align:center;padding:20px;color:#a0a0a0;">Загрузка...</div>';
    try {
        const data = await apiFetch('/api/packages');
        allPkgs = data.apps || [];
        renderPkgs();
    } catch (e) {
        list.innerHTML = '<div style="color:#ff9090;padding:20px;">Ошибка: ' + e.message + '</div>';
    }
}

function renderPkgs() {
    const list = document.getElementById('pkgsList');
    const q = (document.getElementById('pkgsSearch').value || '').toLowerCase();

    let filtered = allPkgs.filter(a => !q || a.package.toLowerCase().includes(q));
    if (pkgsFilter === 'user')     filtered = filtered.filter(a => !a.isSystem);
    if (pkgsFilter === 'system')   filtered = filtered.filter(a => a.isSystem);
    if (pkgsFilter === 'disabled') filtered = filtered.filter(a => a.isDisabled);

    if (filtered.length === 0) {
        list.innerHTML = '<div style="text-align:center;padding:20px;color:#a0a0a0;">Ничего не найдено</div>';
        return;
    }

    const shown = filtered.slice(0, 300);
    list.innerHTML = shown.map(a => {
        let cls = a.isSystem ? 'sys' : 'usr';
        if (a.isDisabled) cls = 'disabled';
        let state = a.isDisabled ? ' · отключено' : '';

        return `
            <div class="app-item">
                <div class="info">
                    <div class="pkg ${cls}">
                        ${a.isSystem ? '[SYS] ' : '[USR] '}${esc(a.package)}${state}
                    </div>
                </div>
                <div class="actions">
                    ${a.isDisabled
                        ? `<button class="success" onclick="pkgAction('${escJs(a.package)}','enable')">Вкл</button>`
                        : `<button class="warn" onclick="pkgAction('${escJs(a.package)}','disable')">Откл</button>`}
                    <button class="danger" onclick="pkgAction('${escJs(a.package)}','remove')">Удал</button>
                </div>
            </div>
        `;
    }).join('');

    if (filtered.length > 300) {
        list.innerHTML += `<div style="text-align:center;padding:10px;color:#a0a0a0;font-size:11px;">... и ещё ${filtered.length - 300}</div>`;
    }
}

async function pkgAction(pkg, action) {
    const labels = { disable: 'Отключить', enable: 'Включить', remove: 'Удалить' };
    if (!confirm(`${labels[action]} пакет?\n\n${pkg}`)) return;

    try {
        const data = await apiFetch('/api/packages/action', {
            method: 'POST',
            body: JSON.stringify({ package: pkg, action })
        });
        if (data.success) {
            showToast('Готово', 'ok');
            loadPackages();
        } else {
            showToast(data.raw || 'Ошибка', 'err');
        }
    } catch (e) {
        showToast('Ошибка: ' + e.message, 'err');
    }
}

/* ================= ПИТАНИЕ ================= */
async function powerAction(action) {
    const msgs = {
        reboot:   'Перезагрузить ТВ?',
        sleep:    'Перевести в спящий режим?',
        wakeup:   'Разбудить ТВ?',
        shutdown: 'ВЫКЛЮЧИТЬ телевизор?\n\nПосле выключения связь по ADB пропадёт.'
    };

    if (!confirm(msgs[action] || action)) return;

    try {
        const data = await apiFetch('/api/power/' + action, { method: 'POST' });
        if (data.success) {
            showToast(action, 'ok');
        } else {
            showToast(data.error || 'Ошибка', 'err');
        }
    } catch (e) {
        showToast('Ошибка: ' + e.message, 'err');
    }
}

/* ================= ТАЙМЕР ================= */
async function setTimer(minutes) {
    try {
        const data = await apiFetch('/api/timer/set', {
            method: 'POST',
            body: JSON.stringify({ minutes })
        });
        if (data.success) {
            showToast(`Таймер: ${minutes} мин`, 'ok');
            document.getElementById('timerStatus').innerHTML =
                `<b style="color:#ffc83d;">Таймер: ${minutes} мин</b>`;
        } else {
            showToast(data.error || 'Ошибка', 'err');
        }
    } catch (e) {
        showToast('Ошибка: ' + e.message, 'err');
    }
}

function setTimerFromInput() {
    const val = parseInt(document.getElementById('timerInput').value);
    if (!val || val < 1 || val > 240) {
        showToast('Введите от 1 до 240 минут', 'err');
        return;
    }
    setTimer(val);
}

async function cancelTimer() {
    try {
        await apiFetch('/api/timer/cancel', { method: 'POST' });
        showToast('Таймер отменён', 'ok');
        document.getElementById('timerStatus').innerHTML = 'Таймер не активен';
    } catch (e) {
        showToast('Ошибка: ' + e.message, 'err');
    }
}

/* ================= ОКНА ================= */
async function loadCurrentActivity() {
    try {
        const data = await apiFetch('/api/current-activity');
        document.getElementById('curActText').textContent = data.activity || '—';
    } catch (e) { }
}

async function loadWindows() {
    const list = document.getElementById('windowsList');
    list.innerHTML = '<div style="text-align:center;padding:20px;color:#a0a0a0;">Загрузка...</div>';
    try {
        const data = await apiFetch('/api/windows');
        const wins = data.windows || [];
        if (wins.length === 0) {
            list.innerHTML = '<div style="text-align:center;padding:20px;color:#a0a0a0;">Пусто</div>';
            return;
        }
        list.innerHTML = wins.map(w => `
            <div class="app-item">
                <div class="info">
                    <div class="pkg usr">${esc(w.package)} <span style="color:#808080;">PID ${w.pid}</span></div>
                </div>
                <div class="actions">
                    <button class="danger" onclick="closeApp('${escJs(w.package)}')">Закрыть</button>
                </div>
            </div>
        `).join('');
    } catch (e) {
        list.innerHTML = '<div style="color:#ff9090;padding:20px;">Ошибка: ' + e.message + '</div>';
    }
}

async function closeApp(pkg) {
    if (!confirm('Принудительно закрыть?\n\n' + pkg)) return;
    try {
        await apiFetch('/api/windows/close', {
            method: 'POST',
            body: JSON.stringify({ package: pkg })
        });
        showToast('Закрыто', 'ok');
        setTimeout(loadWindows, 500);
    } catch (e) {
        showToast('Ошибка', 'err');
    }
}

/* ================= ФАЙЛЫ ================= */
async function loadFiles() {
    const list = document.getElementById('filesList');
    list.innerHTML = '<div style="text-align:center;padding:20px;color:#a0a0a0;">Загрузка...</div>';
    document.getElementById('currentPath').textContent = currentFilePath;

    try {
        const data = await apiFetch('/api/files?path=' + encodeURIComponent(currentFilePath));
        const files = data.files || [];

        if (files.length === 0) {
            list.innerHTML = '<div style="text-align:center;padding:20px;color:#a0a0a0;">Папка пуста</div>';
            return;
        }

        files.sort((a, b) => {
            if (a.isDir !== b.isDir) return a.isDir ? -1 : 1;
            return a.name.localeCompare(b.name);
        });

        list.innerHTML = files.map(f => `
            <div class="file-item">
                <div class="name ${f.isDir ? 'dir' : ''}" onclick="${f.isDir ? `enterDir('${escJs(f.fullPath)}')` : 'void(0)'}">
                    ${f.isDir ? '[DIR] ' : '[FILE] '}${esc(f.name)}
                </div>
                <div class="size">${f.isDir ? '' : fmtSize(f.size)}</div>
                <div class="actions">
                    ${!f.isDir ? `<button onclick="downloadFile('${escJs(f.fullPath)}')">Скачать</button>` : ''}
                    <button class="danger" onclick="deleteFile('${escJs(f.fullPath)}')">✕</button>
                </div>
            </div>
        `).join('');
    } catch (e) {
        list.innerHTML = '<div style="color:#ff9090;padding:20px;">Ошибка: ' + e.message + '</div>';
    }
}

function enterDir(path) {
    currentFilePath = path.endsWith('/') ? path : path + '/';
    loadFiles();
}

function navigateUp() {
    if (currentFilePath === '/') return;
    let p = currentFilePath.replace(/\/$/, '');
    let idx = p.lastIndexOf('/');
    currentFilePath = idx > 0 ? p.substring(0, idx + 1) : '/';
    loadFiles();
}

function navigateTo(path) {
    currentFilePath = path;
    loadFiles();
}

function downloadFile(path) {
    const url = '/api/files/download?path=' + encodeURIComponent(path) + '&token=' + encodeURIComponent(TOKEN);
    window.location.href = url;
}

async function deleteFile(path) {
    if (!confirm('Удалить?\n\n' + path)) return;
    try {
        await apiFetch('/api/files/delete', {
            method: 'POST',
            body: JSON.stringify({ path })
        });
        showToast('Удалено', 'ok');
        loadFiles();
    } catch (e) {
        showToast('Ошибка', 'err');
    }
}

/* ================= СКРИНШОТЫ ================= */
async function takeShotAndShow() {
    showToast('Снимаю...');
    try {
        const data = await apiFetch('/api/screenshot/base64');
        if (data.success) {
            openModal('data:image/png;base64,' + data.base64);
            loadShots();
        } else {
            showToast(data.error || 'Ошибка', 'err');
        }
    } catch (e) {
        showToast('Ошибка: ' + e.message, 'err');
    }
}

async function takeShotAndSave() {
    showToast('Снимаю...');
    try {
        const data = await apiFetch('/api/screenshot');
        if (data.success) {
            const kb = data.size ? Math.round(data.size / 1024) : 0;
            showToast('Сохранено: ' + data.file + ' (' + kb + ' КБ)', 'ok');
            loadShots();
        } else {
            showToast(data.error || 'Ошибка', 'err');
        }
    } catch (e) {
        showToast('Ошибка: ' + e.message, 'err');
    }
}

async function loadShots() {
    const grid = document.getElementById('shotsGrid');
    grid.innerHTML = '<div style="grid-column:1/-1;text-align:center;padding:20px;color:#a0a0a0;">Загрузка...</div>';
    try {
        const data = await apiFetch('/api/screenshot/list');
        const files = data.files || [];
        if (files.length === 0) {
            grid.innerHTML = '<div style="grid-column:1/-1;text-align:center;padding:20px;color:#a0a0a0;">Пусто</div>';
            return;
        }
        grid.innerHTML = files.map(f => {
            const src = '/shots/' + encodeURIComponent(f.name);
            return `
                <div class="shot-tile" onclick="openModal('${src}')">
                    <img src="${src}" loading="lazy" alt="">
                    <div class="meta">
                        <b>${esc(f.name.replace(/^TV_screenshot_/, '').replace(/\.png$/, ''))}</b>
                        ${fmtSize(f.size)}
                    </div>
                </div>
            `;
        }).join('');
    } catch (e) {
        grid.innerHTML = `<div style="grid-column:1/-1;color:#ff9090;padding:20px;">Ошибка: ${e.message}</div>`;
    }
}

/* ================= МЕТРИКИ ================= */
async function loadMetrics() {
    try {
        const m = await apiFetch('/api/metrics');
        if (m.error) { showToast(m.error, 'err'); return; }

        document.getElementById('mCpuVal').textContent = m.cpu.usage + '%';
        document.getElementById('mCpuBar').style.width = Math.min(m.cpu.usage, 100) + '%';
        document.getElementById('mCpuCores').textContent = m.cpu.cores || '—';
        document.getElementById('mCpuMax').textContent = m.cpu.maxFreq || '—';
        document.getElementById('mCpuCur').textContent = m.cpu.curFreq || '—';

        const ramTotal = m.ram.total / (1024*1024*1024);
        document.getElementById('mRamVal').textContent = m.ram.usedPct + '%';
        document.getElementById('mRamBar').style.width = m.ram.usedPct + '%';
        document.getElementById('mRamTotal').textContent = ramTotal.toFixed(2) + ' ГБ';
        document.getElementById('mRamFree').textContent = fmtSize(m.ram.available);

        document.getElementById('mStorVal').textContent = m.storage.usedPct + '%';
        document.getElementById('mStorBar').style.width = m.storage.usedPct + '%';
        document.getElementById('mStorTotal').textContent = fmtSize(m.storage.total);
        document.getElementById('mStorFree').textContent = fmtSize(m.storage.free);

        if (m.temperature >= 0) {
            document.getElementById('mTemp').textContent = m.temperature + ' °C';
            document.getElementById('mTempBar').style.width = Math.min(m.temperature * 1.25, 100) + '%';
            let color = '#6ccb5f';
            if (m.temperature > 80) color = '#ff6b6b';
            else if (m.temperature > 60) color = '#ffc83d';
            document.getElementById('mTempBar').style.background = color;
            document.getElementById('mTemp').style.color = color;
        } else {
            document.getElementById('mTemp').textContent = 'н/д';
        }

        document.getElementById('mUptime').textContent = m.uptime || '—';
        document.getElementById('mLoadAvg').textContent = m.loadAvg || '—';
    } catch (e) {
        showToast('Ошибка метрик: ' + e.message, 'err');
    }
}

async function loadMetricsTop() {
    const list = document.getElementById('metricsTopList');
    list.innerHTML = '<div style="text-align:center;padding:10px;color:#a0a0a0;">Загрузка...</div>';
    try {
        const data = await apiFetch('/api/metrics/top');
        const procs = data.procs || [];
        if (procs.length === 0) {
            list.innerHTML = '<div style="text-align:center;padding:10px;color:#a0a0a0;">Пусто</div>';
            return;
        }
        list.innerHTML = procs.map(p => `
            <div class="app-item">
                <div class="info">
                    <div class="pkg usr">${esc(p.name)}</div>
                </div>
                <div style="text-align:right;font-family:Consolas,monospace;font-size:11px;">
                    <div style="color:#ffc83d;">${p.cpu}%</div>
                    <div style="color:#60cdff;">${p.memMb} МБ</div>
                </div>
            </div>
        `).join('');
    } catch (e) {
        list.innerHTML = '<div style="color:#ff9090;padding:10px;">Ошибка: ' + e.message + '</div>';
    }
}

function toggleMetricsAuto() {
    const btn = document.getElementById('metricsAutoBtn');
    if (metricsAutoTimer) {
        clearInterval(metricsAutoTimer);
        metricsAutoTimer = null;
        btn.textContent = 'Авто';
        btn.classList.remove('success');
        btn.classList.add('neutral');
    } else {
        loadMetrics();
        metricsAutoTimer = setInterval(loadMetrics, 3000);
        btn.textContent = 'Стоп';
        btn.classList.remove('neutral');
        btn.classList.add('success');
    }
}

/* ================= ПРЕСЕТЫ ================= */
async function applyPreset(preset) {
    try {
        const data = await apiFetch('/api/presets', {
            method: 'POST',
            body: JSON.stringify({ preset })
        });
        if (data.success) {
            showToast((data.applied.join(', ') || preset), 'ok');
            setTimeout(loadPresetsState, 500);
        } else {
            showToast(data.error || 'Ошибка', 'err');
        }
    } catch (e) {
        showToast('Ошибка: ' + e.message, 'err');
    }
}

async function loadPresetsState() {
    const el = document.getElementById('presetsState');
    el.textContent = 'Загрузка...';
    try {
        const p = await apiFetch('/api/presets');
        let txt = '';
        txt += 'Тайм-аут:    ' + (p.screen_off_timeout || '—') + ' мс\n';
        txt += 'Анимация:    ' + (p.window_animation_scale || '—') + '\n';
        txt += 'Переходы:    ' + (p.transition_animation_scale || '—') + '\n';
        txt += 'Аниматор:    ' + (p.animator_duration_scale || '—') + '\n';
        txt += 'OTA-пакеты:  ' + ((p.ota_packages || []).join(', ') || 'не найдены');
        el.textContent = txt;
    } catch (e) {
        el.textContent = 'Ошибка: ' + e.message;
    }
}

/* ================= BLUETOOTH ================= */
async function loadBluetooth() {
    const status = document.getElementById('btStatus');
    const list = document.getElementById('btBondedList');

    status.innerHTML = '<b>Bluetooth</b><br><span style="color:#a0a0a0;">Загрузка...</span>';
    list.innerHTML = '<div style="text-align:center;padding:20px;color:#a0a0a0;">Загрузка...</div>';

    try {
        const data = await apiFetch('/api/bluetooth');

        if (data.error) {
            status.innerHTML = `<b>Bluetooth</b><br><span style="color:#ff9090;">${esc(data.error)}</span>`;
            list.innerHTML = '';
            return;
        }

        const statusColor = data.enabled ? '#6ccb5f' : '#a0a0a0';
        const statusText = data.enabled ? 'Включён' : 'Выключен';

        status.innerHTML = `
            <b>Bluetooth</b>
            <span style="float:right;color:${statusColor};">${statusText}</span><br>
            <span style="font-size:11px;color:#a0a0a0;">
                Имя: ${esc(data.name || '—')}<br>
                MAC: ${esc(data.address || '—')}
            </span>
        `;

        if (data.enabled) {
            document.getElementById('btEnableBtn').disabled = true;
            document.getElementById('btDisableBtn').disabled = false;
        } else {
            document.getElementById('btEnableBtn').disabled = false;
            document.getElementById('btDisableBtn').disabled = true;
        }

        const bonded = data.bonded || [];
        if (bonded.length === 0) {
            list.innerHTML = '<div style="text-align:center;padding:20px;color:#a0a0a0;">Нет сопряжённых устройств</div>';
            return;
        }

        list.innerHTML = bonded.map(d => `
            <div class="app-item">
                <div class="info">
                    <div class="pkg usr">
                        ${esc(d.name || '—')}
                        ${d.connected ? '<span style="color:#6ccb5f;">· подключено</span>' : ''}
                    </div>
                    <div style="font-size:10px;color:#808080;font-family:Consolas,monospace;">${esc(d.mac)}</div>
                </div>
            </div>
        `).join('');
    } catch (e) {
        status.innerHTML = `<b>Bluetooth</b><br><span style="color:#ff9090;">Ошибка: ${esc(e.message)}</span>`;
        list.innerHTML = '';
    }
}

async function btEnable() {
    try {
        await apiFetch('/api/bluetooth/enable', { method: 'POST' });
        showToast('Bluetooth включён', 'ok');
        setTimeout(loadBluetooth, 1500);
    } catch (e) {
        showToast('Ошибка: ' + e.message, 'err');
    }
}

async function btDisable() {
    if (!confirm('Выключить Bluetooth?\n\nЕсли к ТВ подключён BT-пульт или звук — они отключатся.')) return;
    try {
        await apiFetch('/api/bluetooth/disable', { method: 'POST' });
        showToast('Bluetooth выключен', 'ok');
        setTimeout(loadBluetooth, 1500);
    } catch (e) {
        showToast('Ошибка: ' + e.message, 'err');
    }
}

/* ================= WI-FI ================= */
async function loadWifi() {
    const status = document.getElementById('wifiStatus');
    const details = document.getElementById('wifiDetails');

    status.innerHTML = '<b>Wi-Fi</b><br><span style="color:#a0a0a0;">Загрузка...</span>';
    details.innerHTML = '';

    try {
        const data = await apiFetch('/api/wifi');

        if (data.error) {
            status.innerHTML = `<b>Wi-Fi</b><br><span style="color:#ff9090;">${esc(data.error)}</span>`;
            return;
        }

        const statusColor = data.enabled ? '#6ccb5f' : '#c62828';
        const statusText = data.enabled ? 'Подключён' : 'Отключён';

        status.innerHTML = `
            <b>Wi-Fi</b>
            <span style="float:right;color:${statusColor};">${statusText}</span><br>
            ${data.ssid ? `<span style="font-size:12px;color:#e0e0e0;">Сеть: <b>${esc(data.ssid)}</b></span>` : ''}
        `;

        const rows = [];
        if (data.ip)        rows.push(['IP-адрес', data.ip]);
        if (data.mac)       rows.push(['MAC', data.mac]);
        if (data.bssid)     rows.push(['BSSID', data.bssid]);
        if (data.gateway)   rows.push(['Шлюз', data.gateway]);
        if (data.frequency) rows.push(['Частота', data.frequency]);
        if (data.linkSpeed) rows.push(['Скорость', data.linkSpeed]);
        if (data.signal > -1) rows.push(['Сигнал', data.signal + ' dBm']);

        if (rows.length === 0) {
            details.innerHTML = '<div style="text-align:center;padding:20px;color:#a0a0a0;">Нет данных</div>';
            return;
        }

        details.innerHTML = rows.map(([k, v]) => `
            <div class="info-card" style="display:flex;justify-content:space-between;padding:10px 14px;margin-bottom:4px;">
                <span style="color:#a0a0a0;">${esc(k)}</span>
                <span style="font-family:Consolas,monospace;color:#e0e0e0;">${esc(v)}</span>
            </div>
        `).join('');
    } catch (e) {
        status.innerHTML = `<b>Wi-Fi</b><br><span style="color:#ff9090;">Ошибка: ${esc(e.message)}</span>`;
    }
}

async function openWifiSettings() {
    try {
        await sendKey('SETTINGS');
        showToast('Открываю настройки на ТВ', 'ok');
    } catch (e) {
        showToast('Ошибка', 'err');
    }
}

/* ================= APK ================= */
function initApkUpload() {
    const drop = document.getElementById('apkDropZone');
    const input = document.getElementById('apkFileInput');
    if (!drop || !input) return;

    drop.addEventListener('click', () => input.click());

    drop.addEventListener('dragover', (e) => {
        e.preventDefault();
        drop.classList.add('dragover');
    });
    drop.addEventListener('dragleave', () => {
        drop.classList.remove('dragover');
    });
    drop.addEventListener('drop', (e) => {
        e.preventDefault();
        drop.classList.remove('dragover');
        if (e.dataTransfer.files.length > 0) {
            uploadApk(e.dataTransfer.files[0]);
        }
    });

    input.addEventListener('change', () => {
        if (input.files.length > 0) {
            uploadApk(input.files[0]);
        }
    });
}

function uploadApk(file) {
    const ext = file.name.toLowerCase().split('.').pop();
    if (!['apk', 'apks', 'xapk', 'apkm'].includes(ext)) {
        showToast('Неподдерживаемый формат: .' + ext, 'err');
        return;
    }
    if (file.size > 500 * 1024 * 1024) {
        showToast('Файл больше 500 МБ', 'err');
        return;
    }

    const progressBox = document.getElementById('apkProgress');
    const progressBar = document.getElementById('apkProgressBar');
    const progressText = document.getElementById('apkProgressText');
    const resultBox = document.getElementById('apkResult');

    progressBox.style.display = 'block';
    resultBox.style.display = 'none';
    progressBar.style.width = '0%';
    progressText.textContent = '0%';

    const xhr = new XMLHttpRequest();
    xhr.open('POST', '/api/apk/upload?token=' + encodeURIComponent(TOKEN), true);
    xhr.setRequestHeader('X-Token', TOKEN);
    xhr.setRequestHeader('X-Filename', file.name);
    xhr.setRequestHeader('Content-Type', 'application/octet-stream');

    xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
            const pct = Math.round(e.loaded / e.total * 100);
            progressBar.style.width = pct + '%';
            progressText.textContent = `Загрузка: ${pct}% (${(e.loaded/1024/1024).toFixed(1)} МБ)`;
        }
    };

    xhr.onload = () => {
        progressBox.style.display = 'none';
        resultBox.style.display = 'block';

        try {
            const data = JSON.parse(xhr.responseText);
            if (data.success) {
                resultBox.innerHTML = `<div class="info-card" style="background:#1f3a1f;border-color:#3a5a3a;color:#6ccb5f;">
                    <b>Установлено</b><br>
                    <span style="font-size:11px;">${esc(data.filename)} (${(data.size/1024/1024).toFixed(1)} МБ)</span>
                </div>`;
                showToast('Установлено', 'ok');
            } else {
                resultBox.innerHTML = `<div class="info-card" style="background:#3a1f1f;border-color:#5a3a3a;color:#ff9090;">
                    <b>Ошибка установки</b><br>
                    <pre style="font-size:10px;white-space:pre-wrap;word-break:break-all;margin:6px 0 0 0;">${esc(data.output || data.error || 'неизвестно')}</pre>
                </div>`;
                showToast('Ошибка установки', 'err');
            }
        } catch (e) {
            resultBox.innerHTML = `<div class="info-card" style="background:#3a1f1f;color:#ff9090;">Ошибка разбора ответа</div>`;
        }
    };

    xhr.onerror = () => {
        progressBox.style.display = 'none';
        resultBox.style.display = 'block';
        resultBox.innerHTML = `<div class="info-card" style="background:#3a1f1f;color:#ff9090;">Ошибка соединения</div>`;
    };

    xhr.send(file);
}

/* ================= ЛОГ ================= */
async function loadLog() {
    const view = document.getElementById('logView');
    try {
        const data = await apiFetch('/api/log?lines=150');
        let lines = data.lines;
        if (!lines) { view.textContent = '(пусто)'; return; }
        if (!Array.isArray(lines)) lines = [String(lines)];
        if (lines.length === 0) { view.textContent = '(пусто)'; return; }

        view.innerHTML = lines.map(l => {
            const s = String(l || '');
            const cls = s.includes('[ОШИБКА]') ? 'line-err' :
                        s.includes('[!]')      ? 'line-warn' :
                        s.includes('[OK]')     ? 'line-ok' : '';
            return `<span class="${cls}">${esc(s)}</span>`;
        }).join('\n');
        view.scrollTop = view.scrollHeight;
    } catch (e) {
        view.textContent = 'Ошибка: ' + e.message;
    }
}

function toggleAutoLog() {
    const btn = document.getElementById('logAutoBtn');
    if (autoLogTimer) {
        clearInterval(autoLogTimer);
        autoLogTimer = null;
        btn.textContent = 'Авто';
        btn.classList.remove('success');
        btn.classList.add('neutral');
    } else {
        loadLog();
        autoLogTimer = setInterval(loadLog, 3000);
        btn.textContent = 'Стоп';
        btn.classList.remove('neutral');
        btn.classList.add('success');
    }
}

/* ================= ИНФО ================= */
async function loadInfo() {
    try {
        const data = await apiFetch('/api/status');
        document.getElementById('infoContent').innerHTML =
            `<b>Состояние:</b> ${data.connected ? 'Подключено' : 'Не подключено'}<br>
             <b>IP ТВ:</b> ${esc(data.deviceIp || '—')}<br>
             <b>Версия:</b> ${esc(data.appVersion || '—')}<br>
             <b>Время сервера:</b> ${esc(data.serverTime || '—')}`;
    } catch (e) {
        document.getElementById('infoContent').textContent = 'Ошибка: ' + e.message;
    }
}