// Shared widget glue: theme colours, hinged enter/leave, messages back to Lua.
const pane = () => document.querySelector(".pane");
const send = (action, extra = {}) => window.webkit.messageHandlers.hs.postMessage({ action, ...extra });
const esc = (s) => String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;");

function setTheme(p) {
  const r = document.documentElement.style, c = (k, d) => "#" + (p[k] || d);
  const set = { bg: ["BASE", "1e1e2e"], bg2: ["MANTLE", "181825"], surface: ["SURFACE0", "313244"],
    fg: ["TEXT", "cdd6f4"], sub: ["SUBTEXT0", "a6adc8"], dim: ["OVERLAY0", "6c7086"],
    accent: ["ACCENT", "cba6f7"], a2: ["BLUE", "89b4fa"], a3: ["PINK", "f5c2e7"], a4: ["GREEN", "a6e3a1"],
    warn: ["YELLOW", "f9e2af"], red: ["RED", "f38ba8"] };
  for (const [v, [k, d]] of Object.entries(set)) {
    const h = p[k] || d;
    r.setProperty("--" + v, "#" + h);
    r.setProperty("--" + v + "-rgb", [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16)).join(","));
  }
  r.setProperty("--glass", ".98" /* transparent windows blend partial alpha strongly; .98 ≈ subtle see-through */);
}

function enter() {
  const el = pane();
  el.classList.remove("out");
  void el.offsetWidth; // restart the animation
  el.classList.add("in");
  // WebKit here sometimes freezes a row's stepped fade part-way (e.g. stuck at 75% opacity);
  // once the rows should have landed, drop their animations so every row ends fully visible.
  clearTimeout(el._settle);
  el.classList.remove("settled");
  el._settle = setTimeout(() => el.classList.add("settled"), 1600);
  if (window.onEnter) onEnter();
}

function leave() {
  const el = pane();
  clearTimeout(el._settle);
  el.classList.remove("in", "settled");
  el.classList.add("out");
  if (window.onLeave) onLeave();
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".close").forEach((b) =>
    b.addEventListener("click", (e) => { e.stopPropagation(); send("hide"); }));
});
