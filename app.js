const $ = (selector, parent = document) => parent.querySelector(selector);
const $$ = (selector, parent = document) => [...parent.querySelectorAll(selector)];

const LEGACY_STORAGE = {
  projects: "kanvas_projects",
  library: "kanvas_library",
};

const inspirationProjects = [
  {
    id: "kopi-gula-aren",
    name: "Kampanye Kopi Gula Aren",
    category: "Makanan & Minuman",
    type: "coffee",
    status: "Inspirasi",
    updated: "Diedit 12 menit lalu",
    hasResults: true,
    brandName: "Rumah Seduh",
    headline: "Rasa pulang di setiap tegukan.",
    cta: "Nikmati sekarang",
    primaryColor: "#5a3529",
    format: "Instagram Post · 4:5",
    style: "Eksploratif",
    prompt:
      "Buat poster promosi untuk kopi susu gula aren artisan. Tonjolkan rasa lokal yang premium, hangat, dan cocok untuk anak muda. Gunakan nuansa cokelat karamel dengan tipografi yang berani.",
  },
  {
    id: "lunea-skincare",
    name: "Peluncuran Lunea Skincare",
    category: "Kecantikan",
    type: "skincare",
    status: "Dipilih",
    updated: "Diedit kemarin",
    hasResults: true,
    brandName: "Lunea",
    headline: "Lembut untuk kulitmu, setiap hari.",
    cta: "Temukan perawatanmu",
    primaryColor: "#e6a58b",
    format: "Instagram Post · 4:5",
    style: "Minimal",
    prompt:
      "Kampanye peluncuran skincare yang lembut untuk kulit sensitif. Visual bersih, feminin, tenang, dengan warna peach dan krem.",
  },
  {
    id: "koleksi-raya",
    name: "Koleksi Raya 2026",
    category: "Fashion",
    type: "fashion",
    status: "Draf",
    updated: "Diedit 3 hari lalu",
    hasResults: false,
    brandName: "Koleksi Raya",
    headline: "Rayakan hari istimewa dengan caramu.",
    cta: "Lihat koleksi",
    primaryColor: "#8fa694",
    format: "Instagram Post · 4:5",
    style: "Minimal",
    prompt:
      "Poster koleksi pakaian Hari Raya modern dengan siluet sederhana, warna sage, dan kesan editorial premium.",
  },
];

const concepts = [
  { name: "Editorial Warm", agent: "Agent Aruna", description: "Editorial hangat dan premium" },
  { name: "Promo Berani", agent: "Agent Bima", description: "Kontras kuat dan komersial" },
  { name: "Organik Tenang", agent: "Agent Citra", description: "Natural, lembut, dan lapang" },
  { name: "Urban Lokal", agent: "Agent Dara", description: "Modern dengan konteks lokal" },
  { name: "Artisan Story", agent: "Agent Elang", description: "Detail material dan proses" },
  { name: "Modern Split", agent: "Agent Fajar", description: "Geometris, bersih, asimetris" },
  { name: "Sage Heritage", agent: "Agent Gita", description: "Elegan dan kontemporer" },
  { name: "Graphic Collage", agent: "Agent Harsa", description: "Kolase muda dan ekspresif" },
  { name: "Classic Spotlight", agent: "Agent Intan", description: "Formal, gelap, dan mewah" },
  { name: "Playful Scale", agent: "Agent Jaya", description: "Cerah dengan skala tak terduga" },
];

const copyDefaults = {
  "Makanan & Minuman": { headline: "Rasa yang layak dibagikan.", cta: "Pesan sekarang" },
  Kecantikan: { headline: "Perawatan yang terasa seperti dirimu.", cta: "Temukan sekarang" },
  Fashion: { headline: "Tampil dengan caramu sendiri.", cta: "Lihat koleksi" },
  Jasa: { headline: "Hasil nyata untuk langkah berikutnya.", cta: "Konsultasikan sekarang" },
  Teknologi: { headline: "Cara lebih cerdas untuk bergerak.", cta: "Coba sekarang" },
  Lainnya: { headline: "Ide baik, dibuat lebih berarti.", cta: "Pelajari selengkapnya" },
};

function getPosterFormatClass(format = "") {
  if (String(format).includes("9:16")) return "format-story";
  if (String(format).includes("1:1")) return "format-square";
  return "format-portrait";
}

function getPosterCopy(project = activeProject) {
  const defaults = copyDefaults[project?.category] || copyDefaults.Lainnya;
  const hasValue = (key) => project && Object.prototype.hasOwnProperty.call(project, key);
  return {
    brand: String(hasValue("brandName") ? project.brandName : (project?.name || "Brand lokal")).trim().slice(0, 60),
    headline: String(hasValue("headline") ? project.headline : defaults.headline).trim().slice(0, 100),
    cta: String(hasValue("cta") ? project.cta : defaults.cta).trim().slice(0, 50),
    logo: sanitizeLogoDataUrl(project?.brandLogo || ""),
    logoPosition: normalizeLogoPosition(project?.logoPosition),
  };
}

function getWorkspacePosterCopy() {
  if (!$("#brand-input")) return getPosterCopy();
  return {
    brand: $("#brand-input").value.trim().slice(0, 60),
    headline: $("#headline-input").value.trim().slice(0, 100),
    cta: $("#cta-input").value.trim().slice(0, 50),
    logo: sanitizeLogoDataUrl(activeProject?.brandLogo || ""),
    logoPosition: normalizeLogoPosition(activeProject?.logoPosition),
  };
}

function getLibraryPosterCopy(item) {
  if (item?.posterCopy) {
    return {
      brand: String(Object.prototype.hasOwnProperty.call(item.posterCopy, "brand") ? item.posterCopy.brand : (item.projectName || "Brand lokal")),
      headline: String(Object.prototype.hasOwnProperty.call(item.posterCopy, "headline") ? item.posterCopy.headline : copyDefaults.Lainnya.headline),
      cta: String(Object.prototype.hasOwnProperty.call(item.posterCopy, "cta") ? item.posterCopy.cta : copyDefaults.Lainnya.cta),
      logo: sanitizeLogoDataUrl(item.posterCopy.logo || item.brandLogo || ""),
      logoPosition: normalizeLogoPosition(item.posterCopy.logoPosition || item.logoPosition),
    };
  }
  return getPosterCopy({ name: item?.projectName, category: item?.category });
}

function posterCopyMarkup(copy, { draggableLogo = false } = {}) {
  const headline = escapeHtml(copy.headline).replace(/\n/g, "<br>");
  const logo = sanitizeLogoDataUrl(copy.logo || "");
  const position = normalizeLogoPosition(copy.logoPosition);
  const logoStyle = `left:${position.x * 100}%;top:${position.y * 100}%;width:${position.width * 100}%;`;
  return `${logo ? `<img class="poster-brand-logo${draggableLogo ? " draggable" : ""}" src="${escapeHtml(logo)}" alt="Logo brand" style="${logoStyle}" ${draggableLogo ? 'data-logo-draggable="true" draggable="false"' : ""} />` : ""}${copy.brand ? `<small>${escapeHtml(copy.brand)}</small>` : ""}${headline ? `<strong>${headline}</strong>` : ""}${copy.cta ? `<span>${escapeHtml(copy.cta)}</span>` : ""}`;
}

function posterCopyClass(copy) {
  return (copy.brand || copy.headline || copy.cta) ? "poster-copy" : "poster-copy no-text";
}

function sanitizeLogoDataUrl(value = "") {
  const logo = String(value);
  return /^data:image\/(?:png|jpeg);base64,[a-z0-9+/=]+$/i.test(logo) ? logo : "";
}

function normalizeLogoPosition(value) {
  const x = Number(value?.x);
  const y = Number(value?.y);
  const width = Number(value?.width);
  const safeWidth = Number.isFinite(width) ? Math.min(0.42, Math.max(0.1, width)) : 0.22;
  return {
    x: Number.isFinite(x) ? Math.min(1 - safeWidth, Math.max(0, x)) : 0.71,
    y: Number.isFinite(y) ? Math.min(0.9, Math.max(0, y)) : 0.06,
    width: safeWidth,
  };
}

function inferLogoPositionFromPrompt(prompt, currentPosition) {
  const text = String(prompt).toLowerCase();
  const current = normalizeLogoPosition(currentPosition);
  const positions = [
    { terms: ["kiri atas", "top left", "upper left"], x: 0.06, y: 0.06 },
    { terms: ["kanan atas", "top right", "upper right"], x: 0.72, y: 0.06 },
    { terms: ["kiri bawah", "bottom left", "lower left"], x: 0.06, y: 0.82 },
    { terms: ["kanan bawah", "bottom right", "lower right"], x: 0.72, y: 0.82 },
    { terms: ["tengah atas", "top center", "atas tengah"], x: 0.39, y: 0.06 },
    { terms: ["tengah bawah", "bottom center", "bawah tengah"], x: 0.39, y: 0.82 },
    { terms: ["logo di tengah", "logo tengah", "center logo"], x: 0.39, y: 0.42 },
  ];
  const match = positions.find((candidate) => candidate.terms.some((term) => text.includes(term)));
  return match ? normalizeLogoPosition({ ...current, x: match.x, y: match.y }) : current;
}

let projects = [];
let libraryItems = [];
let activeProject = null;
let activeLibraryItemId = null;
let selectedConcept = null;
let selectedCategory = "Makanan & Minuman";
let generatedImages = [];
let generationInProgress = false;
let saveTimer = null;
let accountStateTimer = null;
let accountStateReady = false;
let currentUser = null;
let accountPreferences = null;
let accountMenuTrigger = null;
let apiHealth = { online: false, configured: false, model: null, provider: null };
let usageState = null;
let selectedAgentIndexes = [0];
let pendingDeleteProjectId = null;
let signupChallengeToken = "";
let signupTurnstileToken = "";
let turnstileWidgetId = null;
let csrfToken = "";
let currentLanguage = localStorage.getItem("layera_language") === "en" ? "en" : "id";

const uiTranslations = new Map(Object.entries({
  "Studio kreatif bertenaga AI": "AI-powered creative studio",
  "Ide bagus dapat": "A great idea can",
  "terlihat": "look",
  "luar biasa.": "extraordinary.",
  "Bawa satu ceritamu dan jelajahi beragam arah visual yang siap membantu bisnismu berkembang.": "Bring one story and explore visual directions designed to help your business grow.",
  "Dibuat untuk bisnis lokal Indonesia.": "Made for Indonesian local businesses.",
  "Dibuat hanya dalam ±2 menit": "Created in about 2 minutes",
  "SELAMAT DATANG": "WELCOME",
  "Masuk ke ruang kreatifmu.": "Enter your creative space.",
  "Belum punya akun?": "Don't have an account?",
  "Daftar gratis": "Sign up free",
  "Kata Sandi": "Password",
  "Lupa kata sandi?": "Forgot password?",
  "Ingat saya": "Remember me",
  "Masuk ke Layera": "Sign in to Layera",
  "AKUN BARU": "NEW ACCOUNT",
  "Mulai ruang kreatifmu.": "Start your creative space.",
  "Sudah punya akun?": "Already have an account?",
  "Masuk di sini": "Sign in here",
  "Nama lengkap": "Full name",
  "Alamat email": "Email",
  "Kata sandi": "Password",
  "Ulangi kata sandi": "Confirm password",
  "Buat akun": "Create account",
  "Dengan melanjutkan, kamu menyetujui": "By continuing, you agree to our",
  "Ketentuan": "Terms",
  "dan": "and",
  "Privasi": "Privacy",
  "kami.": ".",
  "Proyek Baru": "New Project",
  "Proyek Saya": "My Projects",
  "Inspirasi": "Inspiration",
  "Template": "Templates",
  "Segera": "Soon",
  "Makanan & Minuman": "Food & Beverage",
  "Kecantikan": "Beauty",
  "Fashion": "Fashion",
  "Jasa": "Services",
  "Teknologi": "Technology",
  "Lainnya": "Other",
  "Eksploratif": "Explorative",
  "Minimal": "Minimal",
  "Berani": "Bold",
  "Paket Gratis": "Free Plan",
  "Memuat kuota...": "Loading credits...",
  "Lihat paket": "View plans",
  "Bantuan": "Help",
  "Keamanan": "Security",
  "Keluar": "Log out",
  "Selamat Datang, Maya.": "Welcome, Maya.",
  "Apa yang ingin kamu ceritakan hari ini?": "What would you like to create today?",
  "MULAI BERKREASI": "START CREATING",
  "Satu ide.": "One idea.",
  "Banyak kemungkinan.": "Many possibilities.",
  "Ceritakan bisnismu, biarkan tim kreatif AI kami menerjemahkannya menjadi visual.": "Tell us about your business and let our AI creative team turn it into visuals.",
  "Mulai Proyek": "Start a Project",
  "Proyek Terbaru": "Recent Projects",
  "Lihat Semua": "View All",
  "Tip": "Tip",
  "Berikan prompt yang spesifik agar memberikan hasil yang lebih tajam, menuju kepada target audiens yang di inginkan.": "Use a specific prompt to produce sharper results for your intended audience.",
  "Semua Proyek": "All Projects",
  "Buat proyek": "Create project",
  "Koleksi key visual pilihanmu.": "Your selected key visual collection.",
  "Kembali ke proyek": "Back to projects",
  "Belum ada desain tersimpan.": "No saved designs yet.",
  "Buka proyek, pilih hasil AI yang kamu suka, lalu simpan ke Library.": "Open a project, choose an AI result you like, then save it to the Library.",
  "Jelajahi Inspirasi": "Explore Inspiration",
  "Gunakan inspirasi": "Use inspiration",
  "Buat dari nol": "Start from scratch",
  "Ceritakan idemu": "Describe your idea",
  "Semakin spesifik, hasilnya semakin tepat.": "The more specific you are, the more accurate the result.",
  "Apa yang ingin kamu buat?": "What would you like to create?",
  "Sempurnakan prompt": "Enhance prompt",
  "Coba tambahkan:": "Try adding:",
  "Teks poster": "Poster text",
  "Nama brand": "Brand name",
  "Headline": "Headline",
  "Call to action": "Call to action",
  "Logo brand (opsional)": "Brand logo (optional)",
  "Pilih logo": "Choose logo",
  "Hapus logo": "Remove logo",
  "Arah visual": "Visual direction",
  "Atur ulang": "Reset",
  "Format": "Format",
  "Kualitas gambar": "Image quality",
  "Warna utama": "Primary color",
  "Pilih agent kreatif": "Choose creative agents",
  "Paket gratis: pilih 1 agent": "Free plan: choose 1 agent",
  "Paket Gratis mendukung hingga 1MP / HD.": "The Free Plan supports up to 1MP / HD.",
  "Layera Pro mendukung 1MP, 2MP, dan 4MP.": "Layera Pro supports 1MP, 2MP, and 4MP.",
  "Pilih yang paling kamu suka": "Choose your favorite",
  "Hasil kreasimu akan tampil di sini.": "Your creations will appear here.",
  "Buat gambar": "Generate image",
  "Simpan ke Library": "Save to Library",
  "Gunakan desain ini": "Use this design",
  "Unduh": "Download",
  "Edit salinan": "Edit a copy",
  "Duplikat": "Duplicate",
  "Hapus": "Delete",
  "EDIT DI LIBRARY": "EDIT IN LIBRARY",
  "Buat versi baru.": "Create a new version.",
  "Versi awal akan tetap tersimpan.": "The original version will remain saved.",
  "Apa yang ingin kamu ubah?": "What would you like to change?",
  "Lebih Minimal": "More Minimal",
  "Warna Lebih Hangat": "Warmer Colors",
  "Perbesar Produk": "Enlarge Product",
  "Buat variasi baru": "Create new variation",
  "Token kreatifmu sudah habis.": "Your creative credits are depleted.",
  "PAKET GRATIS": "FREE PLAN",
  "LAYERA PRO": "LAYERA PRO",
  "Upgrade ke pro - Rp. 199.999/bln": "Upgrade to Pro - Rp. 199,999/mo",
  "11 kredit / minggu": "11 credits / week",
  "200 kredit / bulan": "200 credits / month",
  "1 gambar 1MP / HD": "1 image at 1MP / HD",
  "Hingga 3 edit": "Up to 3 edits",
  "Untuk 1 brand": "For 1 brand",
  "Hingga ~100 gambar 1MP": "Up to ~100 1MP images",
  "Kualitas 1MP, 2MP, dan 4MP": "1MP, 2MP, and 4MP quality",
  "10 agent dan brand tanpa batas": "10 agents and unlimited brands",
  "Pengaturan Akun": "Account Settings",
  "Profil": "Profile",
  "Preferensi": "Preferences",
  "Sandi Saat Ini": "Current Password",
  "Sandi Baru": "New Password",
  "Perbarui Kata Sandi": "Update Password",
}));

const uiPlaceholders = new Map(Object.entries({
  "Masukkan kata sandi": "Enter your password",
  "Nama yang akan ditampilkan": "Displayed name",
  "Minimal 8 karakter": "At least 8 characters",
  "Ketik ulang kata sandi": "Re-enter your password",
  "Contoh: Buat latar lebih terang dan ukuran produk sedikit lebih besar...": "Example: Make the background brighter and the product slightly larger...",
}));

const originalUiText = new WeakMap();
const originalUiAttributes = new WeakMap();

function translateUiValue(value) {
  const text = String(value).trim();
  if (uiTranslations.has(text)) return uiTranslations.get(text);
  let match = text.match(/^Selamat Datang, (.+)\.$/);
  if (match) return `Welcome, ${match[1]}.`;
  match = text.match(/^(\d+) proyek$/);
  if (match) return `${match[1]} project${match[1] === "1" ? "" : "s"}`;
  match = text.match(/^(\d+) desain$/);
  if (match) return `${match[1]} design${match[1] === "1" ? "" : "s"}`;
  match = text.match(/^(\d+) dari (\d+) kredit tersisa$/);
  if (match) return `${match[1]} of ${match[2]} credits remaining`;
  match = text.match(/^Buat (\d+) gambar$/);
  if (match) return `Generate ${match[1]} image${match[1] === "1" ? "" : "s"}`;
  match = text.match(/^Layera Pro: (\d+) dari 10 agent dipilih$/);
  if (match) return `Layera Pro: ${match[1]} of 10 agents selected`;
  match = text.match(/^Butuh (\d+) kredit · saldo tidak cukup$/);
  if (match) return `Requires ${match[1]} credits · insufficient balance`;
  match = text.match(/^(1MP|2MP|4MP) · (\d+) kredit$/);
  if (match) return `${match[1]} · ${match[2]} credits`;
  match = text.match(/^Kamu sudah menggunakan semua token kreatif yang ada\.\s+Token gratis selanjutnya akan hadir pada (.+?)\.\s+Ayo upgrade ke pro agar dapat membuka potensial terbaik dari program ini, dapat membuat ~100 gambar, bebas memilih behavior agentic, dll\.$/s);
  if (match) return `You have used all available creative credits.\n\nYour next free credits will arrive on ${match[1]}.\n\nUpgrade to Pro to unlock the program's full potential, create ~100 images, choose agentic behavior freely, and more.`;
  return text;
}

function applyLanguage(root = document) {
  const nodes = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  let node;
  while ((node = nodes.nextNode())) {
    if (!node.nodeValue.trim() || node.parentElement?.closest("script, style")) continue;
    if (currentLanguage === "en") {
      if (node.__layeraTranslatedValue === node.nodeValue) continue;
      originalUiText.set(node, node.nodeValue);
      const leading = node.nodeValue.match(/^\s*/)?.[0] || "";
      const trailing = node.nodeValue.match(/\s*$/)?.[0] || "";
      const translated = `${leading}${translateUiValue(node.nodeValue)}${trailing}`;
      node.__layeraTranslatedValue = translated;
      node.nodeValue = translated;
    } else if (originalUiText.has(node)) {
      node.nodeValue = originalUiText.get(node);
      node.__layeraTranslatedValue = null;
      originalUiText.delete(node);
    }
  }
  root.querySelectorAll?.("[placeholder], [title], [aria-label]").forEach((element) => {
    const saved = originalUiAttributes.get(element) || {};
    ["placeholder", "title", "aria-label"].forEach((attribute) => {
      if (!element.hasAttribute(attribute)) return;
      if (currentLanguage === "en") {
        const current = element.getAttribute(attribute);
        if (saved[`${attribute}Translated`] === current) return;
        saved[attribute] = current;
        const translated = uiPlaceholders.get(current) || uiTranslations.get(current) || translateUiValue(current);
        saved[`${attribute}Translated`] = translated;
        element.setAttribute(attribute, translated);
      } else if (saved[attribute] !== undefined) {
        element.setAttribute(attribute, saved[attribute]);
        delete saved[`${attribute}Translated`];
      }
    });
    originalUiAttributes.set(element, saved);
  });
  document.documentElement.lang = currentLanguage;
  const switcher = $("#language-switch");
  if (switcher) {
    switcher.textContent = currentLanguage === "id" ? "EN" : "ID";
    switcher.setAttribute("aria-label", currentLanguage === "id" ? "Switch to English" : "Ganti ke Bahasa Indonesia");
  }
  document.title = currentLanguage === "en" ? "Layera — Creative studio for your business" : "Layera — Studio kreatif untuk bisnismu";
}

const languageObserver = new MutationObserver((mutations) => {
  if (currentLanguage !== "en") return;
  for (const mutation of mutations) {
    if (mutation.type === "characterData") applyLanguage(mutation.target.parentElement || document);
    mutation.addedNodes.forEach((added) => {
      if (added.nodeType === Node.TEXT_NODE) applyLanguage(added.parentElement || document);
      if (added.nodeType === Node.ELEMENT_NODE) applyLanguage(added);
    });
  }
});

function switchLanguage() {
  currentLanguage = currentLanguage === "id" ? "en" : "id";
  localStorage.setItem("layera_language", currentLanguage);
  applyLanguage();
}

function cloneInspirationProjects() {
  return JSON.parse(JSON.stringify(inspirationProjects));
}

function loadLegacyArray(key) {
  try {
    const raw = localStorage.getItem(key);
    if (raw === null) return null;
    const saved = JSON.parse(raw);
    return Array.isArray(saved) ? saved : null;
  } catch {
    return null;
  }
}

async function requestJson(path, options = {}) {
  const method = String(options.method || "GET").toUpperCase();
  const headers = { ...(options.headers || {}) };
  if (options.body) headers["Content-Type"] = "application/json";
  if (!["GET", "HEAD", "OPTIONS"].includes(method) && csrfToken) headers["X-CSRF-Token"] = csrfToken;
  const response = await fetch(path, {
    ...options,
    cache: "no-store",
    headers,
  });
  let data = {};
  try {
    data = await response.json();
  } catch {
    data = {};
  }
  if (!response.ok) {
    const error = new Error(data.message || `Permintaan gagal (${response.status}).`);
    error.status = response.status;
    error.data = data;
    throw error;
  }
  return data;
}

function loadTurnstileScript() {
  if (window.turnstile) return Promise.resolve(window.turnstile);
  const existing = document.querySelector('script[data-layera-turnstile]');
  if (existing) {
    return new Promise((resolve, reject) => {
      existing.addEventListener("load", () => resolve(window.turnstile), { once: true });
      existing.addEventListener("error", () => reject(new Error("Turnstile tidak dapat dimuat.")), { once: true });
    });
  }
  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
    script.async = true;
    script.defer = true;
    script.dataset.layeraTurnstile = "true";
    script.addEventListener("load", () => resolve(window.turnstile), { once: true });
    script.addEventListener("error", () => reject(new Error("Turnstile tidak dapat dimuat.")), { once: true });
    document.head.appendChild(script);
  });
}

async function renderSignupTurnstile(siteKey) {
  const turnstile = await loadTurnstileScript();
  if (!turnstile) throw new Error("Turnstile tidak tersedia.");
  if (turnstileWidgetId !== null) turnstile.remove(turnstileWidgetId);
  signupTurnstileToken = "";
  turnstileWidgetId = turnstile.render("#turnstile-widget", {
    sitekey: siteKey,
    theme: "light",
    callback: (token) => { signupTurnstileToken = token; },
    "expired-callback": () => { signupTurnstileToken = ""; },
    "error-callback": () => { signupTurnstileToken = ""; },
  });
}

function getSignupDeviceIdentity() {
  let deviceId = localStorage.getItem("layera_device_id");
  if (!deviceId) {
    deviceId = globalThis.crypto?.randomUUID?.() || `device-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    localStorage.setItem("layera_device_id", deviceId);
  }
  const screenValue = globalThis.screen ? `${screen.width}x${screen.height}x${screen.colorDepth}` : "screen-unknown";
  return {
    deviceId,
    deviceFingerprint: [navigator.userAgent, navigator.language, screenValue, Intl.DateTimeFormat().resolvedOptions().timeZone].join("|"),
  };
}

async function loadSignupChallenge() {
  const question = $("#captcha-question");
  const input = $("#register-captcha");
  const mathControl = $("#math-captcha");
  const refreshButton = $("#refresh-captcha");
  const turnstileContainer = $("#turnstile-widget");
  if (!question || !input || !mathControl || !turnstileContainer || window.location.protocol === "file:") return;
  question.textContent = "Memuat soal...";
  input.value = "";
  signupChallengeToken = "";
  signupTurnstileToken = "";
  try {
    const data = await requestJson("/api/auth/challenge");
    const usingTurnstile = data.challenge?.mode === "turnstile";
    mathControl.classList.toggle("is-hidden", usingTurnstile);
    refreshButton.classList.toggle("is-hidden", usingTurnstile);
    turnstileContainer.classList.toggle("is-hidden", !usingTurnstile);
    input.required = !usingTurnstile;
    if (usingTurnstile) {
      await renderSignupTurnstile(data.challenge?.siteKey || "");
    } else {
      signupChallengeToken = data.challenge?.token || "";
      question.textContent = data.challenge?.question || "Soal tidak tersedia";
    }
  } catch {
    mathControl.classList.remove("is-hidden");
    refreshButton.classList.remove("is-hidden");
    turnstileContainer.classList.add("is-hidden");
    input.required = true;
    question.textContent = "Muat ulang halaman";
  }
}

async function persistAccountState() {
  if (!accountStateReady || !currentUser) return;
  try {
    await requestJson("/api/state", {
      method: "PUT",
      body: JSON.stringify({ projects, library: libraryItems }),
    });
  } catch (error) {
    if (error.status === 401) {
      showAuthScreen("Sesi kamu telah berakhir. Silakan masuk kembali.");
      return;
    }
    showToast("Penyimpanan tertunda", error.message || "Data akun belum dapat disimpan.", "!");
  }
}

function scheduleAccountStateSave() {
  if (!accountStateReady || !currentUser) return;
  clearTimeout(accountStateTimer);
  accountStateTimer = setTimeout(persistAccountState, 250);
}

function saveProjects() {
  scheduleAccountStateSave();
}

function saveLibrary() {
  updateLibraryCount();
  scheduleAccountStateSave();
}

async function loadAccountState() {
  accountStateReady = false;
  const state = await requestJson("/api/state");
  if (state.initialized) {
    projects = Array.isArray(state.projects) ? state.projects : [];
    libraryItems = Array.isArray(state.library) ? state.library : [];
  } else {
    const legacyProjects = loadLegacyArray(LEGACY_STORAGE.projects);
    const legacyLibrary = loadLegacyArray(LEGACY_STORAGE.library);
    projects = legacyProjects || [];
    libraryItems = legacyLibrary || [];
    accountStateReady = true;
    await persistAccountState();
    localStorage.removeItem(LEGACY_STORAGE.projects);
    localStorage.removeItem(LEGACY_STORAGE.library);
  }
  accountStateReady = true;
}

function updateLibraryCount() {
  const count = libraryItems.length;
  if ($("#library-nav-count")) $("#library-nav-count").textContent = count;
  if ($("#library-count")) $("#library-count").textContent = `${count} desain`;
}

function isSubscriber() {
  return Boolean(usageState?.isPremium || usageState?.isSubscriber || ["premium", "subscriber"].includes(currentUser?.plan));
}

async function refreshUsage() {
  if (!currentUser || window.location.protocol === "file:") return;
  try {
    const data = await requestJson("/api/usage");
    usageState = data.usage;
    currentUser.plan = usageState.plan;
    updatePlanInterface();
  } catch (error) {
    if (error.status === 401) showAuthScreen("Sesi kamu telah berakhir. Silakan masuk kembali.");
  }
}

function updatePlanInterface() {
  const subscriber = isSubscriber();
  const planLabel = usageState?.planLabel || (subscriber ? "Layera Pro" : "Paket Gratis");
  $("#sidebar-plan-name").textContent = planLabel;
  $("#account-menu-plan").textContent = planLabel;
  const credits = usageState?.credits;
  $("#sidebar-plan-usage").textContent = `${credits?.remaining ?? (subscriber ? 200 : 11)} dari ${credits?.limit ?? (subscriber ? 200 : 11)} kredit tersisa`;
  const progress = $("#plan-card .plan-progress i");
  if (progress) progress.style.width = `${Math.max(0, Math.min(100, ((credits?.remaining ?? 0) / (credits?.limit || 1)) * 100))}%`;
  if (!subscriber && selectedAgentIndexes.length > 1) selectedAgentIndexes = [selectedAgentIndexes[0]];
  const qualitySelect = $("#quality-select");
  if (qualitySelect) {
    $$("option", qualitySelect).forEach((option) => { option.disabled = !subscriber && option.value !== "1mp"; });
    if (!subscriber && qualitySelect.value !== "1mp") qualitySelect.value = "1mp";
    $("#quality-plan-note").textContent = subscriber ? "Layera Pro mendukung 1MP, 2MP, dan 4MP." : "Paket Gratis mendukung hingga 1MP / HD.";
  }
  renderAgentSelector();
  updateGenerationControls();
}

function updateGenerationControls() {
  const count = Math.max(1, selectedAgentIndexes.length);
  const subscriber = isSubscriber();
  const quality = $("#quality-select")?.value || "1mp";
  const unitCost = { "1mp": 2, "2mp": 4, "4mp": 8 }[quality] || 2;
  const totalCost = count * unitCost;
  $("#generate-button-label").textContent = `Buat ${count} gambar`;
  $("#agent-plan-note").textContent = subscriber ? `Layera Pro: ${count} dari 10 agent dipilih` : "Paket gratis: pilih 1 agent";
  const note = $("#generation-cost-note");
  if (!note) return;
  const remaining = usageState?.credits?.remaining;
  note.textContent = remaining !== undefined && remaining < totalCost ? `Butuh ${totalCost} kredit · saldo tidak cukup` : `${quality.toUpperCase()} · ${totalCost} kredit`;
}

function showToast(title, message, icon = "✓") {
  const toast = $("#toast");
  $("span", toast).textContent = icon;
  $("strong", toast).textContent = title;
  $("small", toast).textContent = message;
  toast.classList.add("show");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toast.classList.remove("show"), 3000);
}

async function checkApiHealth() {
  const status = $("#api-status");
  if (!status) return;

  if (window.location.protocol === "file:") {
    apiHealth = { online: false, configured: false, model: null, provider: null };
    status.className = "private-note api-status offline";
    status.innerHTML = "<span>●</span> Jalankan server.ps1 untuk mengaktifkan AI.";
    return;
  }

  try {
    const response = await fetch("/api/health", { cache: "no-store" });
    if (!response.ok) throw new Error("Health check gagal");
    const data = await response.json();
    apiHealth = { online: true, configured: Boolean(data.configured), model: data.model, provider: data.provider };
    updateGenerationControls();
    if (data.configured) {
      status.className = "private-note api-status connected";
      const providerLabel = data.provider === "comfyui"
        ? "AI lokal aktif"
        : data.provider === "nevagate"
          ? "NevaGate eksperimen aktif"
          : "OpenAI GPT Image aktif";
      status.innerHTML = `<span>●</span> ${providerLabel} · ${escapeHtml(data.model)}`;
    } else {
      status.className = "private-note api-status offline";
      const message = data.message || (data.provider === "comfyui" ? "Buka ComfyUI Desktop terlebih dahulu." : "API key belum diatur.");
      status.innerHTML = `<span>●</span> Server aktif · ${escapeHtml(message)}`;
    }
  } catch {
    apiHealth = { online: false, configured: false, model: null, provider: null };
    status.className = "private-note api-status offline";
    status.innerHTML = "<span>●</span> Server AI tidak terhubung.";
  }
}

function getUserInitials(name = "") {
  const parts = String(name).trim().split(/\s+/).filter(Boolean);
  return (parts.length > 1 ? `${parts[0][0]}${parts.at(-1)[0]}` : parts[0]?.slice(0, 2) || "KN").toUpperCase();
}

function updateUserInterface() {
  if (!currentUser) return;
  const initials = getUserInitials(currentUser.displayName);
  const firstName = currentUser.displayName.trim().split(/\s+/)[0] || "Kreator";
  $("#user-avatar").textContent = initials;
  $("#mobile-avatar").textContent = initials;
  $("#account-menu-avatar").textContent = initials;
  $("#account-menu-mini-avatar").textContent = initials;
  $("#user-name").textContent = currentUser.displayName;
  $("#user-email").textContent = currentUser.email;
  $("#account-menu-name").textContent = currentUser.displayName;
  $("#account-menu-current-name").textContent = currentUser.displayName;
  $("#account-menu-email").textContent = currentUser.email;
  $("#welcome-title").textContent = `Selamat Datang, ${firstName}.`;
}

function setAuthError(message = "") {
  const error = $("#auth-error");
  error.textContent = message;
  error.classList.toggle("is-hidden", !message);
}

function showAuthMode(mode = "login") {
  const registering = mode === "register";
  $("#login-heading").classList.toggle("is-hidden", registering);
  $("#login-form").classList.toggle("is-hidden", registering);
  $("#register-heading").classList.toggle("is-hidden", !registering);
  $("#register-form").classList.toggle("is-hidden", !registering);
  setAuthError();
  if (registering) loadSignupChallenge();
  setTimeout(() => $(registering ? "#register-name" : "#email").focus(), 50);
}

function showAuthScreen(message = "") {
  clearTimeout(accountStateTimer);
  accountStateReady = false;
  currentUser = null;
  accountPreferences = null;
  usageState = null;
  csrfToken = "";
  selectedAgentIndexes = [0];
  projects = [];
  libraryItems = [];
  activeProject = null;
  generatedImages = [];
  closeAccountMenu();
  closeAllProjectsModal();
  closeHelpModal();
  closeAccountModal();
  $("#app-shell").classList.add("is-hidden");
  $("#auth-screen").classList.remove("is-hidden");
  showAuthMode("login");
  if (message) setAuthError(message);
}

async function enterApp(sessionData, { loadState = true } = {}) {
  currentUser = sessionData.user;
  csrfToken = sessionData.csrfToken || "";
  accountPreferences = sessionData.preferences || {
    defaultFormat: "Instagram Post · 4:5",
    defaultStyle: "Eksploratif",
    primaryColor: "#5a3529",
    startView: "dashboard",
  };
  updateUserInterface();
  if (loadState) await loadAccountState();
  $("#auth-screen").classList.add("is-hidden");
  $("#app-shell").classList.remove("is-hidden");
  renderProjects();
  renderLibrary();
  renderInspirations();
  updatePlanInterface();
  showView(accountPreferences.startView === "library" ? "library" : "dashboard");
  await refreshUsage();
  checkApiHealth();
}

function populateAccountModal() {
  if (!currentUser) return;
  $("#account-name").value = currentUser.displayName;
  $("#account-email").value = currentUser.email;
  $("#preference-format").value = accountPreferences.defaultFormat;
  $("#preference-style").value = accountPreferences.defaultStyle;
  $("#preference-color").value = accountPreferences.primaryColor;
  $("#preference-start-view").value = accountPreferences.startView;
}

function switchAccountTab(name) {
  $$(".account-tab").forEach((tab) => tab.classList.toggle("active", tab.dataset.accountTab === name));
  $$(".account-panel").forEach((panel) => panel.classList.toggle("is-hidden", panel.dataset.accountPanel !== name));
}

function closeAccountMenu({ restoreFocus = false } = {}) {
  const popover = $("#account-popover");
  if (!popover) return;
  const trigger = accountMenuTrigger;
  popover.classList.add("is-hidden");
  popover.classList.remove("mobile-anchor");
  popover.setAttribute("aria-hidden", "true");
  ["#profile-button", "#mobile-profile-button"].forEach((selector) => {
    $(selector)?.setAttribute("aria-expanded", "false");
  });
  $("#profile-button")?.classList.remove("menu-open");
  accountMenuTrigger = null;
  if (restoreFocus) trigger?.focus();
}

function toggleAccountMenu(trigger) {
  if (!currentUser) return;
  const popover = $("#account-popover");
  const isOpen = !popover.classList.contains("is-hidden");
  if (isOpen) {
    closeAccountMenu();
    return;
  }

  accountMenuTrigger = trigger;
  popover.classList.toggle("mobile-anchor", trigger.id === "mobile-profile-button");
  popover.classList.remove("is-hidden");
  popover.setAttribute("aria-hidden", "false");
  trigger.setAttribute("aria-expanded", "true");
  if (trigger.id === "profile-button") trigger.classList.add("menu-open");
}

function openAccountModal(tab = "profile") {
  if (!currentUser) return;
  closeAccountMenu();
  populateAccountModal();
  switchAccountTab(tab);
  $("#account-modal").classList.remove("is-hidden");
  const focusTarget = {
    profile: "#account-name",
    preferences: "#preference-format",
    security: "#current-password",
  }[tab];
  setTimeout(() => $(focusTarget || "#account-name").focus(), 60);
}

function closeAccountModal() {
  $("#account-modal")?.classList.add("is-hidden");
  $("#password-form")?.reset();
}

async function performLogout() {
  closeAccountMenu();
  closeAccountModal();
  try {
    clearTimeout(accountStateTimer);
    await persistAccountState();
    await requestJson("/api/auth/logout", { method: "POST" });
  } catch {
    // Sesi lokal tetap ditutup meskipun server sedang tidak tersedia.
  }
  showAuthScreen();
  showToast("Kamu sudah keluar", "Sampai jumpa di sesi kreatif berikutnya.", "→");
}

function renderInspirations() {
  const grid = $("#inspiration-grid");
  if (!grid) return;
  grid.innerHTML = cloneInspirationProjects().map((project) => `
    <article class="inspiration-card" data-inspiration-id="${escapeHtml(project.id)}">
      <div class="project-preview ${escapeHtml(project.type)}"><i></i></div>
      <div class="inspiration-card-body">
        <div class="inspiration-card-meta"><i class="status-dot"></i>${escapeHtml(project.category)}</div>
        <h2>${escapeHtml(project.name)}</h2>
        <p>${escapeHtml(project.prompt)}</p>
        <button class="secondary-button" type="button">Gunakan inspirasi <span>→</span></button>
      </div>
    </article>`).join("");
  $$(".inspiration-card", grid).forEach((card) => {
    $("button", card).addEventListener("click", () => createProjectFromInspiration(card.dataset.inspirationId));
  });
}

function createProjectFromInspiration(inspirationId) {
  const source = inspirationProjects.find((project) => project.id === inspirationId);
  if (!source) return;
  const project = {
    ...JSON.parse(JSON.stringify(source)),
    id: `project-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
    status: "Draf",
    updated: "Baru saja",
    hasResults: false,
    generatedImages: [],
    quality: "1mp",
    inspirationSource: source.id,
  };
  projects.unshift(project);
  saveProjects();
  renderProjects();
  openProject(project.id);
  showToast("Inspirasi siap dikembangkan", "Ubah brief, teks poster, dan agent agar sesuai dengan brand-mu.", "✦");
}

const promptSuggestionSets = {
  "Makanan & Minuman": [
    ["Audiens", "Audiens: pelanggan yang mencari pengalaman makan atau minum yang sesuai dengan kebiasaan mereka"],
    ["Momen", "Momen penggunaan: jelaskan kapan dan dalam situasi apa produk dinikmati"],
    ["Detail Visual", "Fokus visual: tekstur produk, bahan utama, penyajian, dan suasana yang menggugah selera"],
  ],
  Kecantikan: [
    ["Audiens", "Audiens: jelaskan kebutuhan kulit, rentang usia, dan kebiasaan perawatan yang dituju"],
    ["Manfaat", "Manfaat utama: tunjukkan hasil dan perasaan yang ingin diasosiasikan dengan produk"],
    ["Suasana", "Suasana visual: bersih, menenangkan, lembut, dan terasa terpercaya"],
  ],
  Fashion: [
    ["Audiens", "Audiens: jelaskan gaya hidup, karakter, dan kesempatan pemakaian koleksi"],
    ["Material", "Detail visual: tonjolkan siluet, material, tekstur kain, dan gerak"],
    ["Suasana", "Suasana visual: editorial, percaya diri, dan relevan dengan musim kampanye"],
  ],
  Lainnya: [
    ["Audiens", "Audiens: jelaskan siapa yang paling membutuhkan produk atau layanan ini"],
    ["Manfaat", "Manfaat utama: jelaskan perubahan atau hasil yang diterima pelanggan"],
    ["Suasana", "Suasana visual: jelaskan emosi, warna, material, dan konteks yang diinginkan"],
  ],
};

function renderPromptSuggestions() {
  const holder = $("#prompt-suggestion-buttons");
  if (!holder) return;
  const category = activeProject?.category || selectedCategory || "Lainnya";
  const suggestions = promptSuggestionSets[category] || promptSuggestionSets.Lainnya;
  holder.innerHTML = suggestions.map(([label, addition]) => `<button type="button" data-add="${escapeHtml(addition)}">+ ${escapeHtml(label)}</button>`).join("");
  $$("button", holder).forEach((button) => button.addEventListener("click", () => {
    const prompt = $("#prompt-input");
    const addition = button.dataset.add;
    if (prompt.value.includes(addition)) return;
    const nextValue = `${prompt.value.trim()}${prompt.value.trim() ? "\n\n" : ""}${addition}.`;
    prompt.value = nextValue.slice(0, 1000);
    updateCharacterCount();
    markSaving();
  }));
}

function renderAgentSelector() {
  const selector = $("#agent-selector");
  if (!selector) return;
  selector.innerHTML = concepts.map((concept, index) => `
    <button class="agent-option ${selectedAgentIndexes.includes(index) ? "selected" : ""}" type="button" data-agent-index="${index}" aria-pressed="${selectedAgentIndexes.includes(index)}" ${generationInProgress ? "disabled" : ""}>
      <b>${String(index + 1).padStart(2, "0")}</b><span><strong>${escapeHtml(concept.agent)}</strong><small>${escapeHtml(concept.name)}</small></span>
    </button>`).join("");
  $$(".agent-option", selector).forEach((button) => button.addEventListener("click", () => toggleAgentSelection(Number(button.dataset.agentIndex))));
}

function toggleAgentSelection(index) {
  if (generationInProgress) return;
  if (!Number.isInteger(index) || index < 0 || index >= concepts.length) return;
  if (!isSubscriber()) {
    selectedAgentIndexes = [index];
  } else if (selectedAgentIndexes.includes(index)) {
    if (selectedAgentIndexes.length === 1) {
      showToast("Pilih minimal satu agent", "Satu agent diperlukan untuk membuat gambar.", "!");
      return;
    }
    selectedAgentIndexes = selectedAgentIndexes.filter((candidate) => candidate !== index);
  } else {
    selectedAgentIndexes = [...selectedAgentIndexes, index].sort((a, b) => a - b);
  }
  if (activeProject) activeProject.agentIndexes = [...selectedAgentIndexes];
  renderAgentSelector();
  updateGenerationControls();
  markSaving();
}

function openUpgradeModal(message = "") {
  if (message) {
    $("#upgrade-modal-message").textContent = message;
  } else if (usageState?.credits?.resetAt) {
    const resetDate = new Intl.DateTimeFormat("id-ID", { day: "numeric", month: "long", year: "numeric" }).format(new Date(usageState.credits.resetAt));
    $("#upgrade-modal-message").textContent = isSubscriber()
      ? `Kredit Layera Pro kamu tidak cukup untuk tindakan ini. Kredit berikutnya hadir pada ${resetDate}.`
      : `Kamu sudah menggunakan semua token kreatif yang ada.\n\nToken gratis selanjutnya akan hadir pada ${resetDate}.\n\nAyo upgrade ke pro agar dapat membuka potensial terbaik dari program ini, dapat membuat ~100 gambar, bebas memilih behavior agentic, dll.`;
  }
  $("#upgrade-modal").classList.remove("is-hidden");
  $("#upgrade-modal").setAttribute("aria-hidden", "false");
  setTimeout(() => $("#upgrade-modal-close").focus(), 50);
}

function closeUpgradeModal() {
  $("#upgrade-modal")?.classList.add("is-hidden");
  $("#upgrade-modal")?.setAttribute("aria-hidden", "true");
}

function renderBrandLogoPreview() {
  const logo = sanitizeLogoDataUrl(activeProject?.brandLogo || "");
  const preview = $("#brand-logo-preview");
  if (!preview) return;
  preview.classList.toggle("is-hidden", !logo);
  $("img", preview).src = logo || "";
}

async function optimizeBrandLogo(file) {
  if (!file || !["image/png", "image/jpeg"].includes(file.type)) throw new Error("Gunakan file PNG, JPG, atau JPEG.");
  if (file.size > 2 * 1024 * 1024) throw new Error("Ukuran logo maksimal 2 MB.");
  const sourceUrl = URL.createObjectURL(file);
  try {
    const image = await loadPosterImage(sourceUrl);
    const maxEdge = 360;
    const scale = Math.min(1, maxEdge / Math.max(image.naturalWidth, image.naturalHeight));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(image.naturalWidth * scale));
    canvas.height = Math.max(1, Math.round(image.naturalHeight * scale));
    canvas.getContext("2d").drawImage(image, 0, 0, canvas.width, canvas.height);
    const result = file.type === "image/png" ? canvas.toDataURL("image/png") : canvas.toDataURL("image/jpeg", 0.86);
    if (result.length > 520000) throw new Error("Logo masih terlalu kompleks. Gunakan file dengan dimensi lebih kecil.");
    return result;
  } finally {
    URL.revokeObjectURL(sourceUrl);
  }
}

function showView(name) {
  closeAccountMenu();
  $("#dashboard-view").classList.toggle("is-hidden", name !== "dashboard");
  $("#library-view").classList.toggle("is-hidden", name !== "library");
  $("#inspiration-view").classList.toggle("is-hidden", name !== "inspiration");
  $("#workspace-view").classList.toggle("is-hidden", name !== "workspace");
  if (name !== "workspace") clearSelection();
  $$(".side-nav .nav-item").forEach((item) => item.classList.toggle("active", item.dataset.route === name));
  $(".sidebar").classList.remove("mobile-open");
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function getLibraryItem(id) {
  return libraryItems.find((item) => item.id === id);
}

function getCurrentLibraryVersion(item) {
  if (!item || !Array.isArray(item.versions) || !item.versions.length) return null;
  return item.versions.find((version) => version.id === item.currentVersionId) || item.versions[0];
}

function renderLibrary() {
  const grid = $("#library-grid");
  if (!grid) return;
  updateLibraryCount();
  $("#library-empty").classList.toggle("is-hidden", libraryItems.length > 0);
  grid.classList.toggle("is-hidden", libraryItems.length === 0);

  grid.innerHTML = libraryItems
    .map((item) => {
      const conceptIndex = Math.max(0, Math.min(concepts.length - 1, Number(item.conceptIndex) || 0));
      const concept = concepts[conceptIndex];
      const versions = Array.isArray(item.versions) ? item.versions : [];
      const current = getCurrentLibraryVersion(item) || {};
      const imageSource = current.url || "";
      const posterCopy = getLibraryPosterCopy(item);
      const formatClass = getPosterFormatClass(item.format);
      const originalId = versions[0]?.id;
      const isOriginal = current.id === originalId;
      return `
        <article class="library-card" data-library-id="${escapeHtml(item.id)}">
          <div class="library-card-preview">
            <div class="poster poster-${conceptIndex + 1} ${formatClass} ${imageSource ? "api-poster" : ""}">
              ${imageSource ? `<img class="generated-image" src="${escapeHtml(imageSource)}" alt="${escapeHtml(item.conceptName || concept.name)}" />` : ""}
              <div class="${posterCopyClass(posterCopy)}">${posterCopyMarkup(posterCopy)}</div>
            </div>
            <span class="library-version-badge">${isOriginal ? "ORIGINAL" : `VERSI ${versions.indexOf(current) + 1}`}</span>
          </div>
          <div class="library-card-body">
            <div class="library-card-title"><div><small>${escapeHtml(item.projectName || "Proyek Kanvas")}</small><h3>${escapeHtml(item.conceptName || concept.name)}</h3></div><span class="original-lock" title="Gambar awal terkunci">◆ Aman</span></div>
            <p>${escapeHtml(item.category || "Bisnis lokal")} · ${versions.length} versi</p>
            <div class="version-strip" aria-label="Pilih versi">
              ${versions.map((version, index) => `<button class="version-pill ${version.id === current.id ? "active" : ""}" data-version-id="${escapeHtml(version.id)}" type="button" title="${escapeHtml(version.refinement || "Gambar original")}">${index === 0 ? "Original" : `V${index + 1}`}</button>`).join("")}
            </div>
            <div class="library-card-actions">
              <button class="secondary-button library-download" type="button">Unduh</button>
              <button class="dark-button library-edit" type="button">✦ Edit salinan</button>
            </div>
          </div>
        </article>`;
    })
    .join("");

  $$(".library-card", grid).forEach((card) => {
    const itemId = card.dataset.libraryId;
    $$(".version-pill", card).forEach((button) => button.addEventListener("click", () => selectLibraryVersion(itemId, button.dataset.versionId)));
    $(".library-edit", card).addEventListener("click", () => openRefineDrawer(itemId));
    $(".library-download", card).addEventListener("click", () => downloadLibraryVersion(itemId));
  });
}

function selectLibraryVersion(itemId, versionId) {
  const item = getLibraryItem(itemId);
  if (!item || !item.versions.some((version) => version.id === versionId)) return;
  item.currentVersionId = versionId;
  saveLibrary();
  renderLibrary();
}

function getProjectCardMarkup(project) {
  return `
    <article class="project-card" data-project-id="${escapeHtml(project.id)}" tabindex="0" role="button" aria-label="Buka ${escapeHtml(project.name)}">
      <div class="project-preview ${escapeHtml(project.type || "empty")}"><i></i></div>
      <div class="project-card-body">
        <h3>${escapeHtml(project.name)}</h3>
        <div class="project-meta"><i class="status-dot ${project.status === "Draf" ? "draft" : ""}"></i>${escapeHtml(project.status)}<span>·</span>${escapeHtml(project.category)}</div>
        <div class="project-card-actions"><span>${escapeHtml(project.updated)}</span><button class="project-options-button" type="button" aria-label="Opsi proyek" aria-expanded="false">•••</button></div>
        <div class="project-action-menu is-hidden" role="menu">
          <button type="button" data-project-action="duplicate" role="menuitem"><span>⧉</span> Duplikat</button>
          <button type="button" data-project-action="delete" class="danger" role="menuitem"><span>⌫</span> Hapus</button>
        </div>
      </div>
    </article>`;
}

function bindProjectCards(grid, { beforeOpen } = {}) {
  $$(".project-card", grid).forEach((card) => {
    const open = () => {
      beforeOpen?.();
      openProject(card.dataset.projectId);
    };
    card.addEventListener("click", (event) => {
      if (!event.target.closest(".project-options-button, .project-action-menu")) open();
    });
    card.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        open();
      }
    });
    const optionsButton = $(".project-options-button", card);
    optionsButton.addEventListener("click", (event) => {
      event.stopPropagation();
      const menu = $(".project-action-menu", card);
      const willOpen = menu.classList.contains("is-hidden");
      $$(".project-action-menu").forEach((candidate) => candidate.classList.add("is-hidden"));
      $$(".project-options-button").forEach((candidate) => candidate.setAttribute("aria-expanded", "false"));
      menu.classList.toggle("is-hidden", !willOpen);
      optionsButton.setAttribute("aria-expanded", String(willOpen));
    });
    $$("[data-project-action]", card).forEach((button) => button.addEventListener("click", (event) => {
      event.stopPropagation();
      if (button.dataset.projectAction === "duplicate") duplicateProject(card.dataset.projectId);
      if (button.dataset.projectAction === "delete") openDeleteProjectModal(card.dataset.projectId);
    }));
  });
}

function duplicateProject(projectId) {
  const source = projects.find((project) => project.id === projectId);
  if (!source) return;
  const copy = JSON.parse(JSON.stringify(source));
  copy.id = `project-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
  copy.name = `${source.name} — Salinan`;
  copy.updated = "Baru saja";
  projects.unshift(copy);
  saveProjects();
  renderProjects();
  if (!$("#all-projects-modal").classList.contains("is-hidden")) renderAllProjects();
  showToast("Proyek diduplikasi", `${copy.name} sudah ditambahkan ke proyekmu.`, "⧉");
}

function openDeleteProjectModal(projectId) {
  const project = projects.find((candidate) => candidate.id === projectId);
  if (!project) return;
  pendingDeleteProjectId = projectId;
  $("#delete-project-name").textContent = project.name;
  $("#delete-project-modal").classList.remove("is-hidden");
  $("#delete-project-modal").setAttribute("aria-hidden", "false");
  setTimeout(() => $("#confirm-delete-project").focus(), 50);
}

function closeDeleteProjectModal() {
  pendingDeleteProjectId = null;
  $("#delete-project-modal")?.classList.add("is-hidden");
  $("#delete-project-modal")?.setAttribute("aria-hidden", "true");
}

function deletePendingProject() {
  const project = projects.find((candidate) => candidate.id === pendingDeleteProjectId);
  if (!project) return closeDeleteProjectModal();
  const deletedProjectId = pendingDeleteProjectId;
  projects = projects.filter((candidate) => candidate.id !== deletedProjectId);
  const deletedActiveProject = activeProject?.id === deletedProjectId;
  closeDeleteProjectModal();
  saveProjects();
  renderProjects();
  if (!$("#all-projects-modal").classList.contains("is-hidden")) renderAllProjects();
  if (deletedActiveProject) {
    activeProject = null;
    showView("dashboard");
  }
  showToast("Proyek dihapus", `${project.name} dihapus. Item Library tetap aman.`, "⌫");
}

function renderProjectCards(grid, projectList, options) {
  grid.innerHTML = projectList.map(getProjectCardMarkup).join("");
  bindProjectCards(grid, options);
}

function renderProjects() {
  $("#project-count").textContent = `${projects.length} proyek`;
  renderProjectCards($("#project-grid"), projects.slice(0, 6));
}

function renderAllProjects() {
  const hasProjects = projects.length > 0;
  $("#all-projects-count").textContent = `${projects.length} proyek`;
  $("#all-projects-grid").classList.toggle("is-hidden", !hasProjects);
  $("#all-projects-empty").classList.toggle("is-hidden", hasProjects);
  renderProjectCards($("#all-projects-grid"), projects, { beforeOpen: closeAllProjectsModal });
}

function escapeHtml(value = "") {
  return String(value).replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "'": "&#39;",
    '"': "&quot;",
  })[character]);
}

function openProject(id) {
  activeProject = projects.find((project) => project.id === id);
  if (!activeProject) return;
  $("#workspace-name").textContent = activeProject.name;
  $("#workspace-category").textContent = activeProject.category;
  $("#prompt-input").value = activeProject.prompt || "";
  const posterCopy = getPosterCopy(activeProject);
  $("#brand-input").value = posterCopy.brand;
  $("#headline-input").value = posterCopy.headline;
  $("#cta-input").value = posterCopy.cta;
  const storedAgents = Array.isArray(activeProject.agentIndexes)
    ? activeProject.agentIndexes.filter((index) => Number.isInteger(index) && index >= 0 && index < concepts.length)
    : [];
  selectedAgentIndexes = storedAgents.length ? [...new Set(storedAgents)] : [0];
  if (!isSubscriber()) selectedAgentIndexes = [selectedAgentIndexes[0]];
  $("#color-control").value = activeProject.primaryColor || accountPreferences?.primaryColor || "#5a3529";
  $("#color-value").textContent = $("#color-control").value.toUpperCase();
  $("#format-select").value = activeProject.format || accountPreferences?.defaultFormat || "Instagram Post · 4:5";
  $("#quality-select").value = activeProject.quality || "1mp";
  if (!isSubscriber()) $("#quality-select").value = "1mp";
  const projectStyle = activeProject.style || accountPreferences?.defaultStyle || "Eksploratif";
  $$(".style-option").forEach((option) => option.classList.toggle("selected", option.dataset.style === projectStyle));
  generatedImages = Array.isArray(activeProject.generatedImages) ? [...activeProject.generatedImages] : [];
  updateCharacterCount();
  renderPromptSuggestions();
  renderAgentSelector();
  updateGenerationControls();
  renderBrandLogoPreview();
  clearSelection();
  showView("workspace");

  if (activeProject.hasResults) {
    $("#empty-results").classList.add("is-hidden");
    renderConcepts(false, generatedImages);
    const resultCount = generatedImages.filter((image) => image?.url).length;
    $("#results-subtitle").textContent = `${resultCount || selectedAgentIndexes.length} gambar dibuat dari brief-mu.`;
  } else {
    $("#results-grid").innerHTML = "";
    $("#empty-results").classList.remove("is-hidden");
    $("#results-subtitle").textContent = "Hasil kreasimu akan tampil di sini.";
  }
}

function openProjectModal() {
  closeAllProjectsModal();
  $("#project-name").value = "";
  $("#project-modal").classList.remove("is-hidden");
  setTimeout(() => $("#project-name").focus(), 80);
}

function closeProjectModal() {
  $("#project-modal").classList.add("is-hidden");
}

function openAllProjectsModal() {
  closeAccountMenu();
  renderAllProjects();
  $("#all-projects-modal").classList.remove("is-hidden");
  $("#all-projects-modal").setAttribute("aria-hidden", "false");
  $("#view-all").setAttribute("aria-expanded", "true");
  setTimeout(() => $("#all-projects-close").focus(), 60);
}

function closeAllProjectsModal({ restoreFocus = false } = {}) {
  const modal = $("#all-projects-modal");
  if (!modal) return;
  const wasOpen = !modal.classList.contains("is-hidden");
  modal.classList.add("is-hidden");
  modal.setAttribute("aria-hidden", "true");
  $("#view-all")?.setAttribute("aria-expanded", "false");
  if (restoreFocus && wasOpen) setTimeout(() => $("#view-all")?.focus(), 0);
}

function openHelpModal() {
  closeAccountMenu();
  closeAllProjectsModal();
  $(".sidebar").classList.remove("mobile-open");
  $("#help-modal").classList.remove("is-hidden");
  $("#help-modal").setAttribute("aria-hidden", "false");
  $("#help-button").setAttribute("aria-expanded", "true");
  setTimeout(() => $("#help-modal-close").focus(), 60);
}

function closeHelpModal({ restoreFocus = false } = {}) {
  const modal = $("#help-modal");
  if (!modal) return;
  const wasOpen = !modal.classList.contains("is-hidden");
  modal.classList.add("is-hidden");
  modal.setAttribute("aria-hidden", "true");
  $("#help-button")?.setAttribute("aria-expanded", "false");
  if (restoreFocus && wasOpen) setTimeout(() => $("#help-button")?.focus(), 0);
}

function renderConcepts(loading = false, images = generatedImages) {
  const posterCopy = getWorkspacePosterCopy();
  const formatClass = getPosterFormatClass($("#format-select")?.value || activeProject?.format);
  const completedIndexes = concepts.map((_, index) => index).filter((index) => images[index]);
  const visibleIndexes = loading ? selectedAgentIndexes : (completedIndexes.length ? completedIndexes : selectedAgentIndexes);
  $("#results-grid").innerHTML = visibleIndexes
    .map((index) => {
      const concept = concepts[index];
      const image = images[index];
      const imageSource = image && (image.displayUrl || image.url);
      const isLoading = loading && !imageSource && !(image && image.error);
      const hasApiImage = Boolean(imageSource);
      return `
        <article class="concept-card ${selectedConcept === index ? "selected" : ""} ${isLoading ? "loading" : ""} ${image && image.error ? "generation-error" : ""}" data-concept="${index}" tabindex="${isLoading ? -1 : 0}" role="button" aria-label="Pilih konsep ${index + 1}: ${concept.name}">
          <span class="concept-check">✓</span>
          <div class="poster poster-${index + 1} ${formatClass} ${hasApiImage ? "api-poster" : ""}">
            ${hasApiImage ? `<img class="generated-image" src="${escapeHtml(imageSource)}" alt="Hasil visual ${escapeHtml(concept.name)}" />` : ""}
            <div class="${posterCopyClass(posterCopy)}">${posterCopyMarkup(posterCopy, { draggableLogo: hasApiImage && !isLoading })}</div>
          </div>
          <div class="concept-meta"><span>${String(index + 1).padStart(2, "0")} · ${concept.name}</span><small>${image && image.error ? "Gagal · coba lagi" : concept.agent}</small></div>
        </article>`;
    })
    .join("");

  bindLogoDragging($("#results-grid"));

  $$(".concept-card:not(.loading)").forEach((card) => {
    if (!card.classList.contains("generation-error")) {
      const select = () => selectConcept(Number(card.dataset.concept));
      card.addEventListener("click", select);
      card.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") select();
      });
    }
  });
}

function bindLogoDragging(root) {
  if (!root) return;
  $$('[data-logo-draggable="true"]', root).forEach((logo) => {
    logo.addEventListener("pointerdown", (event) => {
      if (!activeProject || event.button !== 0) return;
      event.preventDefault();
      event.stopPropagation();
      const poster = logo.closest(".poster");
      const posterRect = poster.getBoundingClientRect();
      const logoRect = logo.getBoundingClientRect();
      const offsetX = event.clientX - logoRect.left;
      const offsetY = event.clientY - logoRect.top;
      logo.setPointerCapture?.(event.pointerId);
      logo.classList.add("dragging");

      const move = (moveEvent) => {
        const current = normalizeLogoPosition(activeProject.logoPosition);
        activeProject.logoPosition = normalizeLogoPosition({
          ...current,
          x: (moveEvent.clientX - posterRect.left - offsetX) / posterRect.width,
          y: (moveEvent.clientY - posterRect.top - offsetY) / posterRect.height,
        });
        const next = activeProject.logoPosition;
        $$('[data-logo-draggable="true"]', root).forEach((candidate) => {
          candidate.style.left = `${next.x * 100}%`;
          candidate.style.top = `${next.y * 100}%`;
          candidate.style.width = `${next.width * 100}%`;
        });
      };
      const finish = () => {
        logo.classList.remove("dragging");
        document.removeEventListener("pointermove", move);
        document.removeEventListener("pointerup", finish);
        document.removeEventListener("pointercancel", finish);
        markSaving();
      };
      document.addEventListener("pointermove", move);
      document.addEventListener("pointerup", finish, { once: true });
      document.addEventListener("pointercancel", finish, { once: true });
    });
  });
}

function selectConcept(index) {
  selectedConcept = index;
  $$(".concept-card").forEach((card) => card.classList.toggle("selected", Number(card.dataset.concept) === index));
  const selected = concepts[index];
  $("#selected-name").textContent = `Konsep ${String(index + 1).padStart(2, "0")} · ${selected.name}`;
  const thumb = $("#selection-bar .selected-thumb");
  const image = generatedImages[index];
  const imageSource = image && (image.displayUrl || image.url);
  thumb.className = `selected-thumb poster poster-${index + 1} ${getPosterFormatClass($("#format-select").value)} ${imageSource ? "api-poster" : ""}`;
  const thumbCopy = getWorkspacePosterCopy();
  thumb.innerHTML = `${imageSource ? `<img class="generated-image" src="${escapeHtml(imageSource)}" alt="" />` : ""}<div class="${posterCopyClass(thumbCopy)}">${posterCopyMarkup(thumbCopy)}</div>`;
  const savedItem = findSavedSelection(index);
  $("#save-library-button").textContent = savedItem ? "✓ Sudah di Library" : "◇ Simpan ke Library";
  $("#selection-bar").classList.remove("is-hidden");
}

function clearSelection() {
  selectedConcept = null;
  $$(".concept-card.selected").forEach((card) => card.classList.remove("selected"));
  $("#selection-bar").classList.add("is-hidden");
}

function findSavedSelection(index = selectedConcept) {
  if (index === null || !activeProject) return null;
  const image = generatedImages[index];
  const sourceUrl = image?.url || "";
  return libraryItems.find((item) => item.projectId === activeProject.id && Number(item.conceptIndex) === index && (item.sourceUrl || "") === sourceUrl);
}

function saveSelectedToLibrary() {
  if (selectedConcept === null || !activeProject) {
    showToast("Pilih desain terlebih dahulu", "Klik salah satu hasil generasi yang ingin disimpan.", "!");
    return;
  }

  const existing = findSavedSelection();
  if (existing) {
    existing.posterCopy = getWorkspacePosterCopy();
    existing.primaryColor = $("#color-control").value;
    saveLibrary();
    renderLibrary();
    showView("library");
    showToast("Teks poster diperbarui", "Copy terbaru diterapkan tanpa membuat ulang key visual.", "✓");
    return;
  }

  const image = generatedImages[selectedConcept] || {};
  if (!image.url) {
    showToast("Belum ada key visual AI", "Buat gambar terlebih dahulu sebelum menyimpan desain ke Library.", "!");
    return;
  }
  const concept = concepts[selectedConcept];
  const createdAt = new Date().toISOString();
  const itemId = `library-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
  const originalVersionId = `${itemId}-v1`;
  const sourceUrl = image.url || "";
  libraryItems.unshift({
    id: itemId,
    projectId: activeProject.id,
    projectName: activeProject.name,
    category: activeProject.category,
    prompt: $("#prompt-input").value.trim(),
    format: $("#format-select").value,
    style: $(".style-option.selected strong")?.textContent || "Eksploratif",
    primaryColor: $("#color-control").value,
    quality: $("#quality-select").value,
    posterCopy: getWorkspacePosterCopy(),
    conceptIndex: selectedConcept,
    conceptName: concept.name,
    agent: concept.agent,
    sourceUrl,
    createdAt,
    currentVersionId: originalVersionId,
    versions: [{ id: originalVersionId, url: sourceUrl, refinement: "", createdAt, immutable: true }],
  });
  saveLibrary();
  renderLibrary();
  $("#save-library-button").textContent = "✓ Sudah di Library";
  showToast("Tersimpan ke Library", "Original dikunci. Editing berikutnya akan dibuat sebagai versi baru.", "◇");
}

async function startGeneration() {
  if (generationInProgress) return;
  const prompt = $("#prompt-input").value.trim();
  const requestId = globalThis.crypto?.randomUUID?.() || `generation-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  if (prompt.length < 20) {
    showToast("Brief masih terlalu singkat", "Tambahkan sedikit detail tentang produk atau audiensmu.", "!");
    $("#prompt-input").focus();
    return;
  }

  const requestedQuality = $("#quality-select").value;
  const requestedCreditCost = selectedAgentIndexes.length * ({ "1mp": 2, "2mp": 4, "4mp": 8 }[requestedQuality] || 2);
  if (usageState?.generation?.exhausted || (usageState?.credits && usageState.credits.remaining < requestedCreditCost)) {
    openUpgradeModal();
    return;
  }
  if (activeProject?.brandLogo) activeProject.logoPosition = inferLogoPositionFromPrompt(prompt, activeProject.logoPosition);

  if (window.location.protocol === "file:") {
    showToast("Server AI belum berjalan", "Jalankan server.ps1 lalu buka http://localhost:8000.", "!");
    return;
  }

  const previousImages = [...generatedImages];
  const requestedAgentIndexes = [...selectedAgentIndexes];
  const requestedCount = requestedAgentIndexes.length;
  const imageModelLabel = apiHealth.provider === "openai" ? "GPT Image" : apiHealth.provider === "nevagate" ? apiHealth.model || "NevaGate" : "Qwen";
  generationInProgress = true;
  generatedImages = Array(10).fill(null);
  clearSelection();
  $("#empty-results").classList.add("is-hidden");
  $("#generation-progress").classList.remove("is-hidden");
  $("#generate-button").disabled = true;
  renderConcepts(true, generatedImages);
  $("#results-subtitle").textContent = `${imageModelLabel} mengeksplorasi ${requestedCount} arah visual.`;
  const progressTitle = $("#progress-title");
  if (progressTitle) progressTitle.textContent = `${imageModelLabel} sedang membuat key visual...`;
  setGenerationProgress(3, `Menyiapkan ${imageModelLabel} dan ${requestedCount} agent kreatif`);

  try {
    const selectedStyle = $(".style-option.selected strong")?.textContent || "Eksploratif";
    const response = await fetch("/api/generate", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken },
      body: JSON.stringify({
        requestId,
        prompt,
        projectName: activeProject?.name || "Proyek Kanvas",
        category: activeProject?.category || "Bisnis lokal",
        format: $("#format-select").value,
        style: selectedStyle,
        primaryColor: $("#color-control").value,
        agentIndexes: requestedAgentIndexes,
        quality: requestedQuality,
        brandName: $("#brand-input").value.trim() || activeProject?.name || "",
      }),
    });

    if (response.status === 401) {
      showAuthScreen("Sesi kamu telah berakhir. Silakan masuk kembali.");
      throw new Error("Sesi login telah berakhir.");
    }

    if (!response.ok) {
      let errorData = {};
      try {
        errorData = await response.json();
      } catch {
        errorData.message = `Server merespons dengan status ${response.status}.`;
      }
      const requestError = new Error(errorData.message || "Generasi gambar gagal.");
      requestError.data = errorData;
      throw requestError;
    }

    if (!response.body) throw new Error("Browser tidak mendukung streaming hasil gambar.");
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    let completed = false;
    let completedImages = 0;

    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        if (!line.trim()) continue;
        const event = JSON.parse(line);
        if (event.type === "start") {
          if (event.requestId !== requestId || Number(event.promptLength) !== prompt.length) {
            throw new Error("Backend menerima brief yang tidak cocok. Muat ulang halaman lalu coba lagi.");
          }
          apiHealth.model = event.model;
          setGenerationProgress(5, `Brief diterima utuh (${event.promptLength} karakter) · ${event.model}`);
        }
        if (event.type === "progress") {
          const percent = Math.min(92, 8 + (completedImages / requestedCount) * 82);
          setGenerationProgress(percent, `${imageModelLabel} mengeksplorasi arah ${event.name}`);
        }
        if (event.type === "image") {
          generatedImages[event.index] = {
            url: event.url,
            displayUrl: event.displayUrl,
            name: event.name,
            agent: event.agent,
          };
          renderConcepts(true, generatedImages);
          completedImages += 1;
          const percent = Math.min(96, 10 + (completedImages / requestedCount) * 86);
          setGenerationProgress(Math.round(percent), `${completedImages} dari ${requestedCount} gambar selesai`);
        }
        if (event.type === "image_error") {
          generatedImages[event.index] = { error: true, message: event.message };
          renderConcepts(true, generatedImages);
        }
        if (event.type === "done") {
          if (event.requestId !== requestId) throw new Error("Respons generasi tidak cocok dengan permintaan ini.");
          completed = true;
          finishGeneration(event.success, event.failed, event.firstError, event.usage);
        }
      }
    }

    if (!completed) {
      throw new Error("Koneksi terputus sebelum semua agent selesai.");
    }
  } catch (error) {
    if (error.data?.usage) {
      usageState = error.data.usage;
      updatePlanInterface();
    }
    if (error.data?.upgradeRequired) openUpgradeModal(error.message);
    const hasNewImages = generatedImages.some((image) => image && image.url);
    if (!hasNewImages) generatedImages = previousImages;
    renderConcepts(false, generatedImages);
    $("#generation-progress").classList.add("is-hidden");
    $("#generate-button").disabled = false;
    $("#results-subtitle").textContent = "Generasi belum selesai. Brief-mu tetap tersimpan.";
    const fallback = apiHealth.provider === "comfyui"
      ? "Periksa ComfyUI dan workflow Qwen, lalu coba lagi."
      : apiHealth.provider === "nevagate"
        ? "Periksa key NevaGate atau coba model lain yang mampu menulis SVG."
        : "Periksa server dan API key, lalu coba lagi.";
    showToast("Generasi AI gagal", error.message || fallback, "!");
  } finally {
    generationInProgress = false;
    renderAgentSelector();
  }
}

function setGenerationProgress(percent, label) {
  $("#progress-percent").textContent = `${percent}%`;
  $("#progress-label").textContent = label;
  $("#progress-bar").style.width = `${percent}%`;
}

function finishGeneration(reportedSuccess = 0, reportedFailed = 0, firstError = "", latestUsage = null) {
  if (latestUsage) {
    usageState = latestUsage;
    updatePlanInterface();
  }
  const receivedSuccess = generatedImages.filter((image) => image && (image.url || image.displayUrl)).length;
  const successCount = Math.max(Number(reportedSuccess) || 0, receivedSuccess);
  const failedCount = Math.max(Number(reportedFailed) || 0, generatedImages.filter((image) => image?.error).length);
  renderConcepts(false, generatedImages);
  $("#generation-progress").classList.add("is-hidden");
  $("#generate-button").disabled = false;
  $("#results-subtitle").textContent = failedCount > 0 ? `${successCount} gambar selesai · ${failedCount} gagal.` : `${successCount} gambar AI dibuat dari brief-mu.`;
  if (activeProject) {
    activeProject.hasResults = successCount > 0;
    activeProject.status = `${successCount} gambar`;
    activeProject.updated = "Baru saja";
    activeProject.prompt = $("#prompt-input").value.trim();
    activeProject.format = $("#format-select").value;
    activeProject.style = $(".style-option.selected")?.dataset.style || "Eksploratif";
    const posterCopy = getWorkspacePosterCopy();
    activeProject.brandName = posterCopy.brand;
    activeProject.headline = posterCopy.headline;
    activeProject.cta = posterCopy.cta;
    activeProject.primaryColor = $("#color-control").value;
    activeProject.quality = $("#quality-select").value;
    activeProject.brandLogo = sanitizeLogoDataUrl(activeProject.brandLogo || "");
    activeProject.agentIndexes = [...selectedAgentIndexes];
    activeProject.generatedImages = generatedImages.map((image) => (image && image.url ? { url: image.url } : null));
    saveProjects();
  }
  if (successCount > 0) {
    const message = failedCount > 0 ? `${failedCount} gambar gagal, tetapi hasil yang selesai tetap dapat dipilih.` : "Pilih satu desain yang paling mewakili bisnismu.";
    showToast(`${successCount} gambar sudah siap`, message, "✦");
  } else {
    const cardError = generatedImages.find((image) => image?.error)?.message || "";
    const conciseError = String(firstError || cardError).split("\n")[0].slice(0, 220);
    const providerMessage = apiHealth.provider === "comfyui"
      ? "Periksa jendela ComfyUI dan pastikan workflow Qwen tidak menampilkan error."
      : apiHealth.provider === "nevagate"
        ? "Model NevaGate mungkin mengembalikan teks biasa dan bukan SVG. Coba Kimi K3 atau Claude lain."
        : "Periksa API key, billing, atau rate limit akun OpenAI.";
    showToast("Belum ada gambar yang selesai", conciseError || providerMessage, "!");
  }
}

function updateCharacterCount() {
  $("#char-count").textContent = $("#prompt-input").value.length;
}

function markSaving() {
  if (!activeProject) return;
  $("#save-status").innerHTML = "<i></i> Menyimpan...";
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    activeProject.prompt = $("#prompt-input").value;
    activeProject.format = $("#format-select").value;
    activeProject.style = $(".style-option.selected")?.dataset.style || "Eksploratif";
    const posterCopy = getWorkspacePosterCopy();
    activeProject.brandName = posterCopy.brand;
    activeProject.headline = posterCopy.headline;
    activeProject.cta = posterCopy.cta;
    activeProject.primaryColor = $("#color-control").value;
    activeProject.quality = $("#quality-select").value;
    activeProject.brandLogo = sanitizeLogoDataUrl(activeProject.brandLogo || "");
    activeProject.agentIndexes = [...selectedAgentIndexes];
    saveProjects();
    $("#save-status").innerHTML = "<i></i> Tersimpan";
  }, 700);
}

function openRefineDrawer(itemId) {
  const item = getLibraryItem(itemId);
  if (!item) {
    showToast("Simpan ke Library terlebih dahulu", "Editing hanya tersedia untuk salinan yang sudah masuk Library.", "!");
    return;
  }
  activeLibraryItemId = itemId;
  const conceptIndex = Math.max(0, Math.min(concepts.length - 1, Number(item.conceptIndex) || 0));
  const currentVersion = getCurrentLibraryVersion(item);
  const imageSource = currentVersion?.url || "";
  const poster = $("#drawer-poster");
  poster.className = `poster poster-${conceptIndex + 1} ${getPosterFormatClass(item.format)} ${imageSource ? "api-poster" : ""}`;
  const drawerCopy = getLibraryPosterCopy(item);
  poster.innerHTML = `${imageSource ? `<img class="generated-image" src="${escapeHtml(imageSource)}" alt="" />` : ""}<div class="${posterCopyClass(drawerCopy)}">${posterCopyMarkup(drawerCopy)}</div>`;
  const versionNumber = Math.max(1, item.versions.findIndex((version) => version.id === currentVersion?.id) + 1);
  $("#drawer-version-meta").textContent = `Mengedit versi ${versionNumber}. Hasilnya akan disimpan sebagai V${item.versions.length + 1}; original tetap aman.`;
  $("#drawer-scrim").classList.remove("is-hidden");
  $("#refine-drawer").classList.add("open");
  $("#refine-drawer").setAttribute("aria-hidden", "false");
}

function closeRefineDrawer() {
  $("#drawer-scrim").classList.add("is-hidden");
  $("#refine-drawer").classList.remove("open");
  $("#refine-drawer").setAttribute("aria-hidden", "true");
}

async function regenerateSelected() {
  const libraryItem = getLibraryItem(activeLibraryItemId);
  if (!libraryItem) {
    closeRefineDrawer();
    showToast("Item Library tidak ditemukan", "Simpan desain ke Library sebelum melakukan editing.", "!");
    return;
  }
  const input = $("#refine-input");
  if (!input.value.trim()) {
    input.focus();
    showToast("Tuliskan perubahanmu", "Cukup satu detail kecil agar hasil tetap konsisten.", "✦");
    return;
  }
  if (usageState?.refinement?.exhausted || (usageState?.credits && usageState.credits.remaining < 3)) {
    openUpgradeModal();
    return;
  }
  if (window.location.protocol === "file:") {
    showToast("Server AI belum berjalan", "Buka aplikasi melalui http://localhost:8000.", "!");
    return;
  }
  const button = $("#regenerate-button");
  button.disabled = true;
  $("strong", button).textContent = "Membuat variasi...";

  try {
    const response = await fetch("/api/refine", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken },
      body: JSON.stringify({
        prompt: libraryItem.prompt,
        refinement: input.value.trim(),
        conceptIndex: libraryItem.conceptIndex,
        projectName: libraryItem.projectName || "Proyek Kanvas",
        category: libraryItem.category || "Bisnis lokal",
        format: libraryItem.format || "Instagram Post · 4:5",
        style: libraryItem.style || "Eksploratif",
        primaryColor: libraryItem.primaryColor || "",
        quality: libraryItem.quality || "1mp",
        sourceUrl: getCurrentLibraryVersion(libraryItem)?.url || libraryItem.sourceUrl,
      }),
    });
    if (response.status === 401) {
      showAuthScreen("Sesi kamu telah berakhir. Silakan masuk kembali.");
      throw new Error("Sesi login telah berakhir.");
    }
    const data = await response.json();
    if (!response.ok) {
      const requestError = new Error(data.message || "Variasi baru gagal dibuat.");
      requestError.data = data;
      throw requestError;
    }
    if (data.usage) {
      usageState = data.usage;
      updatePlanInterface();
    }

    const versionNumber = libraryItem.versions.length + 1;
    const versionId = `${libraryItem.id}-v${versionNumber}-${Date.now()}`;
    libraryItem.versions.push({
      id: versionId,
      url: data.url,
      refinement: input.value.trim(),
      createdAt: new Date().toISOString(),
      immutable: false,
    });
    libraryItem.currentVersionId = versionId;
    saveLibrary();
    renderLibrary();
    closeRefineDrawer();
    input.value = "";
    showToast(`Versi ${versionNumber} selesai`, "Versi baru disimpan di Library; gambar original tidak berubah.", "✦");
  } catch (error) {
    if (error.data?.usage) {
      usageState = error.data.usage;
      updatePlanInterface();
    }
    if (error.data?.upgradeRequired) openUpgradeModal(error.message);
    showToast("Refinement gagal", error.message || "Periksa koneksi AI lalu coba lagi.", "!");
  } finally {
    button.disabled = false;
    $("strong", button).textContent = "Buat variasi baru";
  }
}

function useSelectedDesign() {
  if (selectedConcept === null || !activeProject) return;
  activeProject.status = "Dipilih";
  activeProject.updated = "Baru saja";
  activeProject.selectedConcept = selectedConcept;
  saveProjects();
  showToast("Desain utama dipilih", "Simpan ke Library jika kamu ingin membuat versi edit tanpa mengubah original.", "✓");
}

function loadPosterImage(url) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("File key visual tidak dapat dimuat."));
    image.src = url;
  });
}

function getCanvasTextLines(context, text, maxWidth, maxLines = 3) {
  const words = String(text).trim().split(/\s+/).filter(Boolean);
  const lines = [];
  let current = "";
  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (current && context.measureText(candidate).width > maxWidth) {
      lines.push(current);
      current = word;
      if (lines.length === maxLines - 1) break;
    } else {
      current = candidate;
    }
  }
  if (current && lines.length < maxLines) lines.push(current);
  const consumed = lines.join(" ").split(/\s+/).length;
  if (consumed < words.length && lines.length) {
    let finalLine = lines[lines.length - 1];
    while (finalLine && context.measureText(`${finalLine}…`).width > maxWidth) finalLine = finalLine.slice(0, -1).trim();
    lines[lines.length - 1] = `${finalLine}…`;
  }
  return lines.length ? lines : [""];
}

async function downloadComposedPoster(imageUrl, posterCopy, fileName) {
  const source = await loadPosterImage(imageUrl);
  const canvas = document.createElement("canvas");
  canvas.width = source.naturalWidth;
  canvas.height = source.naturalHeight;
  const context = canvas.getContext("2d");
  context.drawImage(source, 0, 0, canvas.width, canvas.height);

  const width = canvas.width;
  const height = canvas.height;
  const padding = Math.round(width * 0.075);
  const hasPosterText = Boolean(posterCopy.brand || posterCopy.headline || posterCopy.cta);
  if (hasPosterText) {
    const gradient = context.createLinearGradient(0, height * 0.38, 0, height);
    gradient.addColorStop(0, "rgba(8,8,6,0)");
    gradient.addColorStop(0.52, "rgba(8,8,6,0.18)");
    gradient.addColorStop(1, "rgba(8,8,6,0.9)");
    context.fillStyle = gradient;
    context.fillRect(0, 0, width, height);
  }

  const logoUrl = sanitizeLogoDataUrl(posterCopy.logo || "");
  if (logoUrl) {
    try {
      const logo = await loadPosterImage(logoUrl);
      const position = normalizeLogoPosition(posterCopy.logoPosition);
      const maxLogoWidth = width * position.width;
      const maxLogoHeight = height * 0.18;
      const logoScale = Math.min(maxLogoWidth / logo.naturalWidth, maxLogoHeight / logo.naturalHeight, 1);
      const logoWidth = Math.max(1, Math.round(logo.naturalWidth * logoScale));
      const logoHeight = Math.max(1, Math.round(logo.naturalHeight * logoScale));
      context.drawImage(logo, width * position.x, height * position.y, logoWidth, logoHeight);
    } catch {
      // Ekspor teks tetap dapat dilanjutkan jika data logo lama tidak dapat dibaca.
    }
  }

  context.textBaseline = "alphabetic";
  context.shadowColor = "rgba(0,0,0,.45)";
  context.shadowBlur = Math.max(2, Math.round(width * 0.008));
  context.fillStyle = "#ffffff";
  const brandSize = Math.max(14, Math.round(width * 0.025));
  context.font = `800 ${brandSize}px Arial, sans-serif`;
  if (posterCopy.brand) context.fillText(String(posterCopy.brand).toUpperCase(), padding, padding + brandSize);

  const ctaSize = Math.max(13, Math.round(width * 0.022));
  context.font = `800 ${ctaSize}px Arial, sans-serif`;
  const ctaText = String(posterCopy.cta || "").toUpperCase();
  const ctaPadX = Math.round(width * 0.022);
  const ctaHeight = Math.round(ctaSize * 2.05);
  const ctaWidth = Math.min(width - padding * 2, Math.ceil(context.measureText(ctaText).width + ctaPadX * 2));
  const ctaY = height - padding - ctaHeight;
  if (ctaText) {
    context.shadowBlur = 0;
    context.fillStyle = "#d9ff5b";
    context.fillRect(padding, ctaY, ctaWidth, ctaHeight);
    context.fillStyle = "#26301b";
    context.fillText(ctaText, padding + ctaPadX, ctaY + Math.round(ctaHeight * 0.67));
  }

  let headlineSize = Math.max(28, Math.round(width * 0.066));
  context.font = `600 ${headlineSize}px Georgia, serif`;
  const headlineLines = posterCopy.headline ? getCanvasTextLines(context, posterCopy.headline, width - padding * 2, 3) : [];
  const lineHeight = Math.round(headlineSize * 1.04);
  const headlineBottom = (ctaText ? ctaY - Math.round(height * 0.035) : height - padding);
  const headlineStart = headlineBottom - (headlineLines.length - 1) * lineHeight;
  context.shadowBlur = Math.max(2, Math.round(width * 0.009));
  context.fillStyle = "#ffffff";
  headlineLines.forEach((line, index) => context.fillText(line, padding, headlineStart + index * lineHeight));

  const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png", 0.94));
  if (!blob) throw new Error("Browser gagal menyusun file poster.");
  const objectUrl = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = objectUrl;
  link.download = `${fileName}.png`;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
}

async function exportSelectedImage() {
  if (selectedConcept === null) {
    showToast("Pilih satu konsep dulu", "Klik poster yang paling kamu suka sebelum mengekspor.", "↓");
    return;
  }

  const image = generatedImages[selectedConcept];
  if (!image || !image.url) {
    showToast("Belum ada file AI", "Buat konsep melalui server AI agar dapat mengunduh gambar asli.", "!");
    return;
  }

  const safeName = (activeProject?.name || "kanvas")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
  try {
    await downloadComposedPoster(image.url, getWorkspacePosterCopy(), `${safeName}-konsep-${String(selectedConcept + 1).padStart(2, "0")}`);
    showToast("Poster siap", "Key visual dan teks poster sudah digabungkan sebagai PNG.", "↓");
  } catch (error) {
    showToast("Ekspor gagal", error.message || "Poster tidak dapat disusun.", "!");
  }
}

async function downloadLibraryVersion(itemId) {
  const item = getLibraryItem(itemId);
  const version = getCurrentLibraryVersion(item);
  if (!item || !version?.url) {
    showToast("Belum ada file AI", "Versi demo CSS tidak memiliki file gambar untuk diunduh.", "!");
    return;
  }
  const versionIndex = item.versions.findIndex((candidate) => candidate.id === version.id) + 1;
  const safeName = `${item.projectName || "kanvas"}-${item.conceptName || "desain"}`
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
  try {
    await downloadComposedPoster(version.url, getLibraryPosterCopy(item), `${safeName}-v${versionIndex}`);
    showToast("Poster siap", `Versi ${versionIndex} sudah digabungkan dengan teks poster.`, "↓");
  } catch (error) {
    showToast("Unduhan gagal", error.message || "Versi ini tidak dapat disusun.", "!");
  }
}

function bindEvents() {
  $("#language-switch").addEventListener("click", switchLanguage);
  $("#login-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const button = $("#login-form .auth-submit");
    button.disabled = true;
    setAuthError();
    try {
      const session = await requestJson("/api/auth/login", {
        method: "POST",
        body: JSON.stringify({
          email: $("#email").value.trim(),
          password: $("#password").value,
          remember: $("#login-remember").checked,
        }),
      });
      await enterApp(session);
      $("#password").value = "";
    } catch (error) {
      setAuthError(error.message || "Kanvas belum dapat menghubungi server akun.");
    } finally {
      button.disabled = false;
    }
  });
  $("#register-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const password = $("#register-password").value;
    if (password !== $("#register-confirm").value) {
      setAuthError("Konfirmasi kata sandi belum cocok.");
      return;
    }
    const button = $("#register-form .auth-submit");
    button.disabled = true;
    setAuthError();
    try {
      const session = await requestJson("/api/auth/register", {
        method: "POST",
        body: JSON.stringify({
          displayName: $("#register-name").value.trim(),
          email: $("#register-email").value.trim(),
          password,
          remember: $("#register-remember").checked,
          captchaToken: signupChallengeToken,
          captchaAnswer: $("#register-captcha").value.trim(),
          turnstileToken: signupTurnstileToken,
          ...getSignupDeviceIdentity(),
        }),
      });
      await enterApp(session);
      $("#register-form").reset();
      showToast("Akun berhasil dibuat", "Ruang kreatif pribadimu sudah siap digunakan.", "✓");
    } catch (error) {
      setAuthError(error.message || "Akun belum dapat dibuat.");
      loadSignupChallenge();
    } finally {
      button.disabled = false;
    }
  });
  $("#refresh-captcha").addEventListener("click", loadSignupChallenge);
  $("#show-register").addEventListener("click", () => showAuthMode("register"));
  $("#show-login").addEventListener("click", () => showAuthMode("login"));
  $("#toggle-password").addEventListener("click", () => {
    const password = $("#password");
    password.type = password.type === "password" ? "text" : "password";
  });
  $(".text-button.subtle").addEventListener("click", () => showToast("Pemulihan belum aktif", "Untuk versi lokal, ubah kata sandi dari Pengaturan setelah masuk.", "i"));

  ["#profile-button", "#mobile-profile-button"].forEach((selector) => {
    $(selector).addEventListener("click", (event) => toggleAccountMenu(event.currentTarget));
  });
  $$('[data-account-open]').forEach((button) => {
    button.addEventListener("click", () => openAccountModal(button.dataset.accountOpen));
  });
  $("#account-menu-logout").addEventListener("click", performLogout);
  $("#account-modal-close").addEventListener("click", closeAccountModal);
  $("#account-modal").addEventListener("click", (event) => {
    if (event.target === event.currentTarget) closeAccountModal();
  });
  $$(".account-tab").forEach((tab) => tab.addEventListener("click", () => switchAccountTab(tab.dataset.accountTab)));
  $("#profile-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    try {
      const data = await requestJson("/api/account/profile", {
        method: "PUT",
        body: JSON.stringify({ displayName: $("#account-name").value.trim() }),
      });
      currentUser = data.user;
      updateUserInterface();
      showToast("Profil diperbarui", "Nama akunmu sudah tersimpan.", "✓");
    } catch (error) {
      showToast("Profil belum tersimpan", error.message, "!");
    }
  });
  $("#preferences-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    try {
      const data = await requestJson("/api/account/preferences", {
        method: "PUT",
        body: JSON.stringify({
          defaultFormat: $("#preference-format").value,
          defaultStyle: $("#preference-style").value,
          primaryColor: $("#preference-color").value,
          startView: $("#preference-start-view").value,
        }),
      });
      accountPreferences = data.preferences;
      showToast("Preferensi disimpan", "Proyek berikutnya akan memakai pilihan ini.", "✓");
    } catch (error) {
      showToast("Preferensi belum tersimpan", error.message, "!");
    }
  });
  $("#password-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const newPassword = $("#new-password").value;
    if (newPassword !== $("#confirm-new-password").value) {
      showToast("Kata sandi belum cocok", "Ulangi kata sandi baru dengan nilai yang sama.", "!");
      return;
    }
    try {
      const data = await requestJson("/api/account/password", {
        method: "PUT",
        body: JSON.stringify({ currentPassword: $("#current-password").value, newPassword }),
      });
      csrfToken = data.csrfToken || csrfToken;
      $("#password-form").reset();
      showToast("Kata sandi diperbarui", "Sesi lain sudah dikeluarkan demi keamanan.", "✓");
    } catch (error) {
      showToast("Kata sandi belum berubah", error.message, "!");
    }
  });
  document.addEventListener("click", (event) => {
    const popover = $("#account-popover");
    if (popover.classList.contains("is-hidden")) return;
    if (popover.contains(event.target) || event.target.closest("#profile-button, #mobile-profile-button")) return;
    closeAccountMenu();
  });
  document.addEventListener("click", (event) => {
    if (event.target.closest(".project-options-button, .project-action-menu")) return;
    $$(".project-action-menu").forEach((menu) => menu.classList.add("is-hidden"));
    $$(".project-options-button").forEach((button) => button.setAttribute("aria-expanded", "false"));
  });
  window.addEventListener("resize", closeAccountMenu);

  ["#new-project-side", "#new-project-main", "#quick-create"].forEach((selector) => $(selector)?.addEventListener("click", openProjectModal));
  $$('[data-close-modal]').forEach((button) => button.addEventListener("click", closeProjectModal));
  $("#project-modal").addEventListener("click", (event) => {
    if (event.target === event.currentTarget) closeProjectModal();
  });
  $("#view-all").addEventListener("click", openAllProjectsModal);
  $("#all-projects-close").addEventListener("click", () => closeAllProjectsModal({ restoreFocus: true }));
  $("#all-projects-modal").addEventListener("click", (event) => {
    if (event.target === event.currentTarget) closeAllProjectsModal({ restoreFocus: true });
  });
  $("#all-projects-create").addEventListener("click", openProjectModal);
  $("#delete-project-close").addEventListener("click", closeDeleteProjectModal);
  $("#cancel-delete-project").addEventListener("click", closeDeleteProjectModal);
  $("#confirm-delete-project").addEventListener("click", deletePendingProject);
  $("#delete-project-modal").addEventListener("click", (event) => {
    if (event.target === event.currentTarget) closeDeleteProjectModal();
  });
  $("#help-button").addEventListener("click", openHelpModal);
  $("#help-modal-close").addEventListener("click", () => closeHelpModal({ restoreFocus: true }));
  $("#help-modal").addEventListener("click", (event) => {
    if (event.target === event.currentTarget) closeHelpModal({ restoreFocus: true });
  });
  $("#upgrade-plan-button").addEventListener("click", () => openUpgradeModal());
  $("#upgrade-modal-close").addEventListener("click", closeUpgradeModal);
  $("#upgrade-modal").addEventListener("click", (event) => {
    if (event.target === event.currentTarget) closeUpgradeModal();
  });
  $("#upgrade-contact-button").addEventListener("click", () => {
    closeUpgradeModal();
    closeDeleteProjectModal();
    openHelpModal();
  });
  $$(".category-option").forEach((button) =>
    button.addEventListener("click", () => {
      $$(".category-option").forEach((option) => option.classList.remove("selected"));
      button.classList.add("selected");
      selectedCategory = button.dataset.category;
    }),
  );
  $("#project-form").addEventListener("submit", (event) => {
    event.preventDefault();
    const name = $("#project-name").value.trim();
    const project = {
      id: `project-${Date.now()}`,
      name,
      category: selectedCategory,
      type: "empty",
      status: "Draf",
      updated: "Baru saja",
      hasResults: false,
      brandName: name,
      headline: (copyDefaults[selectedCategory] || copyDefaults.Lainnya).headline,
      cta: (copyDefaults[selectedCategory] || copyDefaults.Lainnya).cta,
      primaryColor: accountPreferences?.primaryColor || "#5a3529",
      format: accountPreferences?.defaultFormat || "Instagram Post · 4:5",
      style: accountPreferences?.defaultStyle || "Eksploratif",
      prompt: "",
      brandLogo: "",
      quality: "1mp",
      agentIndexes: [0],
    };
    projects.unshift(project);
    saveProjects();
    renderProjects();
    closeProjectModal();
    openProject(project.id);
    showToast("Proyek baru dibuat", "Mulai dengan menceritakan ide promosimu.", "✦");
  });

  $$('[data-route="dashboard"]').forEach((button) => button.addEventListener("click", (event) => {
    event.preventDefault();
    renderProjects();
    showView("dashboard");
  }));
  $("#library-nav").addEventListener("click", () => {
    renderLibrary();
    showView("library");
  });
  $('[data-route="inspiration"]').addEventListener("click", () => {
    renderInspirations();
    showView("inspiration");
  });
  $("#inspiration-create").addEventListener("click", openProjectModal);
  ["#library-to-projects", "#library-empty-projects"].forEach((selector) => $(selector).addEventListener("click", () => {
    renderProjects();
    showView("dashboard");
  }));
  $$(".side-nav .nav-item").forEach((button) => {
    if (!["dashboard", "library", "inspiration"].includes(button.dataset.route)) button.addEventListener("click", () => showToast("Fitur sedang disiapkan", "Untuk sekarang, lanjutkan eksplorasi dari proyekmu.", "✦"));
  });
  $("#back-dashboard").addEventListener("click", () => {
    renderProjects();
    showView("dashboard");
  });
  $("#mobile-menu").addEventListener("click", () => $(".sidebar").classList.toggle("mobile-open"));
  $("#dismiss-tip").addEventListener("click", () => $(".tips-strip").remove());

  $("#prompt-input").addEventListener("input", () => {
    updateCharacterCount();
    markSaving();
  });
  ["#brand-input", "#headline-input", "#cta-input"].forEach((selector) =>
    $(selector).addEventListener("input", () => {
      markSaving();
      if (activeProject?.hasResults) renderConcepts(false, generatedImages);
    }),
  );
  $("#brand-logo-input").addEventListener("change", async (event) => {
    const file = event.target.files?.[0];
    if (!file || !activeProject) return;
    try {
      activeProject.brandLogo = await optimizeBrandLogo(file);
      renderBrandLogoPreview();
      markSaving();
      if (activeProject.hasResults) renderConcepts(false, generatedImages);
      showToast("Logo ditambahkan", "Logo akan ikut tampil pada preview, Library, dan file ekspor.", "✓");
    } catch (error) {
      showToast("Logo belum dapat digunakan", error.message, "!");
    } finally {
      event.target.value = "";
    }
  });
  $("#remove-brand-logo").addEventListener("click", () => {
    if (!activeProject) return;
    activeProject.brandLogo = "";
    renderBrandLogoPreview();
    markSaving();
    if (activeProject.hasResults) renderConcepts(false, generatedImages);
  });
  $("#magic-prompt").addEventListener("click", async () => {
    const button = $("#magic-prompt");
    const prompt = $("#prompt-input");
    button.disabled = true;
    const originalLabel = button.textContent;
    button.textContent = "Menyempurnakan...";
    try {
      const data = await requestJson("/api/prompt-enhance", {
        method: "POST",
        body: JSON.stringify({
          prompt: prompt.value.trim(),
          projectName: activeProject?.name || "",
          category: activeProject?.category || "Lainnya",
          style: $(".style-option.selected")?.dataset.style || "Eksploratif",
          format: $("#format-select").value,
          brand: $("#brand-input").value.trim(),
          headline: $("#headline-input").value.trim(),
          cta: $("#cta-input").value.trim(),
        }),
      });
      prompt.value = String(data.prompt || "").slice(0, 1000);
      updateCharacterCount();
      markSaving();
      showToast("Prompt disempurnakan", "Arahan kini mengikuti kategori, brand, format, dan tujuan proyek ini.", "✦");
    } catch (error) {
      showToast("Prompt belum dapat disempurnakan", error.message || "Periksa koneksi server lalu coba lagi.", "!");
    } finally {
      button.disabled = false;
      button.textContent = originalLabel;
    }
  });
  $$(".style-option").forEach((button) =>
    button.addEventListener("click", () => {
      $$(".style-option").forEach((option) => option.classList.remove("selected"));
      button.classList.add("selected");
      markSaving();
    }),
  );
  $("#format-select").addEventListener("change", () => {
    markSaving();
    if (activeProject?.hasResults) renderConcepts(false, generatedImages);
  });
  $("#quality-select").addEventListener("change", () => {
    if (!isSubscriber() && $("#quality-select").value !== "1mp") {
      $("#quality-select").value = "1mp";
      openUpgradeModal("Kualitas 2MP dan 4MP tersedia pada Layera Pro.");
    }
    updateGenerationControls();
    markSaving();
  });
  $("#reset-controls").addEventListener("click", () => {
    const preferredStyle = accountPreferences?.defaultStyle || "Eksploratif";
    $$(".style-option").forEach((option) => option.classList.toggle("selected", option.dataset.style === preferredStyle));
    $("#format-select").value = accountPreferences?.defaultFormat || "Instagram Post · 4:5";
    $("#color-control").value = accountPreferences?.primaryColor || "#5a3529";
    $("#color-value").textContent = $("#color-control").value.toUpperCase();
    markSaving();
    if (activeProject?.hasResults) renderConcepts(false, generatedImages);
  });
  $("#color-control").addEventListener("input", () => {
    $("#color-value").textContent = $("#color-control").value.toUpperCase();
    markSaving();
  });
  $("#generate-button").addEventListener("click", startGeneration);

  $$(".view-toggles button").forEach((button) =>
    button.addEventListener("click", () => {
      $$(".view-toggles button").forEach((toggle) => toggle.classList.remove("active"));
      button.classList.add("active");
      $("#results-grid").classList.toggle("large", button.dataset.cols === "2");
    }),
  );
  $("#clear-selection").addEventListener("click", clearSelection);
  $("#save-library-button").addEventListener("click", saveSelectedToLibrary);
  $("#use-design-button").addEventListener("click", useSelectedDesign);
  $("#close-drawer").addEventListener("click", closeRefineDrawer);
  $("#drawer-scrim").addEventListener("click", closeRefineDrawer);
  $$(".refine-chips button").forEach((button) =>
    button.addEventListener("click", () => {
      const input = $("#refine-input");
      input.value = input.value ? `${input.value}, ${button.textContent.toLowerCase()}` : button.textContent;
    }),
  );
  $("#regenerate-button").addEventListener("click", regenerateSelected);
  $("#export-button").addEventListener("click", exportSelectedImage);

  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    closeAccountMenu({ restoreFocus: true });
    closeProjectModal();
    closeAllProjectsModal({ restoreFocus: true });
    closeHelpModal({ restoreFocus: true });
    closeAccountModal();
    closeUpgradeModal();
    closeRefineDrawer();
    $(".sidebar").classList.remove("mobile-open");
  });
}

async function bootstrap() {
  const accountPopover = $("#account-popover");
  accountPopover.setAttribute("aria-hidden", "true");
  document.body.appendChild(accountPopover);
  bindEvents();
  languageObserver.observe(document.body, { childList: true, subtree: true, characterData: true });
  applyLanguage();
  updateCharacterCount();
  localStorage.removeItem("kanvas_session");

  try {
    const session = await requestJson("/api/auth/me");
    await enterApp(session);
  } catch (error) {
    const message = error.status && error.status !== 401 ? error.message : "";
    showAuthScreen(message);
  }
  document.documentElement.dataset.appReady = "true";
}

bootstrap();
