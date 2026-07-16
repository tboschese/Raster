// engine.js — Raster's Web core: Markdown → HTML (marked + highlight.js + mermaid),
// the reading-mode WYSIWYG (contenteditable + turndown), outline/stats extraction,
// in-document find, and the Swift⇄JS bridge described in CLAUDE.md.
//
// Everything here is offline: marked/highlight.js/mermaid/turndown are loaded from
// WebCore/vendor (see index.html), never a CDN.

(function () {
  "use strict";

  const state = {
    markdown: "",
    theme: "dark",
    rfont: "serif",
    lang: "system",
    layout: "split", // "split" | "reading" — controls the reading measure only
    editing: false, // WYSIWYG contenteditable on/off
    findQuery: "",
    findIndex: 0,
    findMatches: [],
    lastEditedByUser: false,
  };

  function post(type, payload) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.raster) {
      window.webkit.messageHandlers.raster.postMessage({ type, payload });
    }
  }

  function resolvedLang() {
    if (state.lang && state.lang !== "system") return state.lang;
    const nav = (navigator.language || "en").toLowerCase();
    return nav.startsWith("pt") ? "pt-BR" : "en";
  }

  function t() {
    return window.RasterStrings.resolve(resolvedLang());
  }

  // ---------- marked configuration ----------
  const renderer = new marked.Renderer();
  const slugCounts = {};

  function slugify(raw) {
    let s = raw
      .toLowerCase()
      .replace(/[`*_~[\]()]/g, "")
      .trim()
      .replace(/[^a-z0-9À-ſ]+/g, "-")
      .replace(/^-+|-+$/g, "");
    if (!s) s = "h";
    if (slugCounts[s] != null) {
      slugCounts[s] += 1;
      s = `${s}-${slugCounts[s]}`;
    } else {
      slugCounts[s] = 0;
    }
    return s;
  }

  let outline = [];

  renderer.heading = function (text, level, raw) {
    const id = slugify(raw);
    if (level <= 3) outline.push({ level, title: raw.replace(/[`*_~]/g, ""), id });
    return `<h${level} class="md-h md-h${level}" id="${id}">${text}</h${level}>\n`;
  };
  renderer.paragraph = function (text) {
    return `<p class="md-p">${text}</p>\n`;
  };
  renderer.link = function (href, title, text) {
    const t = title ? ` title="${title}"` : "";
    return `<a class="md-a" href="${href}"${t}>${text}</a>`;
  };
  renderer.codespan = function (code) {
    return `<code class="md-icode">${code}</code>`;
  };
  renderer.hr = function () {
    return `<hr class="md-hr">\n`;
  };
  renderer.image = function (href, title, text) {
    return `<img class="md-img" src="${href}" alt="${text || ""}" data-mdsrc="${href}">`;
  };
  renderer.list = function (body, ordered) {
    const tag = ordered ? "ol" : "ul";
    return `<${tag} class="md-list">\n${body}</${tag}>\n`;
  };
  renderer.listitem = function (text, task, checked) {
    if (task) {
      const done = !!checked;
      const inner = text.replace(/^\s*<input[^>]*>\s*/, "");
      return (
        `<li class="md-task${done ? " md-task-done" : ""}" data-task="${done ? "x" : " "}">` +
        `<span class="md-check" contenteditable="false">${done ? "☑" : "☐"}</span>` +
        `<span class="md-task-text">${inner}</span></li>\n`
      );
    }
    return `<li>${text}</li>\n`;
  };
  renderer.table = function (header, body) {
    return `<table class="md-table"><thead>${header}</thead><tbody>${body}</tbody></table>\n`;
  };
  renderer.blockquote = function (quote) {
    const m = quote.match(/^\s*<p class="md-p">\[!(NOTE|TIP|WARNING|IMPORTANT|CAUTION)\]\s*<\/p>\s*([\s\S]*)$/);
    if (m) {
      const kind = m[1];
      const body = m[2];
      const label = t().callouts[kind] || kind;
      return (
        `<div class="md-callout md-callout-${kind.toLowerCase()}" data-callout="${kind}">` +
        `<div class="md-callout-label" contenteditable="false">▸ ${label}</div>` +
        `<div class="md-callout-body">${body}</div></div>\n`
      );
    }
    return `<blockquote class="md-quote">${quote}</blockquote>\n`;
  };
  renderer.code = function (code, infostring) {
    const lang = (infostring || "").trim().toLowerCase();
    if (lang === "mermaid") {
      const id = "mmd-" + Math.random().toString(36).slice(2, 10);
      return `<div class="md-mermaid" data-src="${escapeHtml(code)}" data-mmid="${id}" contenteditable="false"><span class="mm-pending">…</span></div>\n`;
    }
    const known = hljs.getLanguage(lang) ? lang : null;
    const highlighted = known ? hljs.highlight(code, { language: known }).value : escapeHtml(code);
    return (
      `<div class="md-codeblock" data-src="${escapeHtml(code)}" data-lang="${escapeHtml(lang)}" contenteditable="false">` +
      `<div class="md-codebtns"><button class="md-copy" type="button">${t().copy}</button></div>` +
      `<pre><code class="hljs">${highlighted}</code></pre></div>\n`
    );
  };

  marked.setOptions({ renderer, gfm: true, breaks: false });

  function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  // ---------- stats ----------
  function computeStats(md) {
    const stripped = md.replace(/```[\s\S]*?```/g, " ").replace(/[#>*`~\-|[\]()!]/g, " ");
    const words = (stripped.match(/\S+/g) || []).length;
    return { words, readingMinutes: Math.max(1, Math.round(words / 200)) };
  }

  // ---------- mermaid ----------
  let mermaidReady = false;
  function initMermaid() {
    mermaid.initialize({
      startOnLoad: false,
      theme: state.theme === "light" ? "neutral" : "dark",
      securityLevel: "strict",
      fontFamily: "var(--sans)",
    });
    mermaidReady = true;
  }

  async function renderMermaidBlocks(root) {
    const blocks = [...root.querySelectorAll(".md-mermaid[data-mmid]")];
    for (const block of blocks) {
      const src = block.getAttribute("data-src") || "";
      const id = block.getAttribute("data-mmid");
      try {
        const { svg } = await mermaid.render(id + "-svg", src);
        block.innerHTML = svg;
      } catch (err) {
        block.classList.add("md-mermaid-error");
        block.innerHTML = `<span class="mm-err">✕ ${t().mermaidError}</span><pre class="mm-errsrc">${escapeHtml(src)}</pre>`;
      }
    }
  }

  // ---------- outline / active heading (scroll-spy) ----------
  function computeActiveHeading() {
    const doc = document.getElementById("doc");
    const scroller = document.getElementById("scroller");
    if (!doc || !scroller) return null;
    const headings = [...doc.querySelectorAll(".md-h")];
    if (!headings.length) return null;
    const top = scroller.getBoundingClientRect().top + 30;
    let current = headings[0].id;
    for (const h of headings) {
      if (h.getBoundingClientRect().top - top <= 0) current = h.id;
      else break;
    }
    return current;
  }

  let lastActiveHeading = null;
  function onScroll() {
    const id = computeActiveHeading();
    if (id && id !== lastActiveHeading) {
      lastActiveHeading = id;
      post("didChangeActiveHeading", { id });
    }
  }

  // ---------- render pipeline ----------
  function render() {
    outline = [];
    Object.keys(slugCounts).forEach((k) => delete slugCounts[k]);
    const doc = document.getElementById("doc");
    if (!doc) return;
    doc.innerHTML = marked.parse(state.markdown || "");
    if (mermaidReady) renderMermaidBlocks(doc).finally(() => post("didFinishRender", null));
    else post("didFinishRender", null);
    post("didUpdateOutline", outline);
    post("didUpdateStats", computeStats(state.markdown || ""));
    lastActiveHeading = null;
    onScroll();
    applyFind();
  }

  // ---------- turndown (WYSIWYG → Markdown) ----------
  const td = new TurndownService({ headingStyle: "atx", codeBlockStyle: "fenced", bulletListMarker: "-" });
  td.addRule("mdCodeblock", {
    filter: (node) => node.classList && node.classList.contains("md-codeblock"),
    replacement: (_content, node) => {
      const lang = node.getAttribute("data-lang") || "";
      const src = node.getAttribute("data-src") || "";
      return `\n\n\`\`\`${lang}\n${src}\n\`\`\`\n\n`;
    },
  });
  td.addRule("mdMermaid", {
    filter: (node) => node.classList && node.classList.contains("md-mermaid"),
    replacement: (_content, node) => {
      const src = node.getAttribute("data-src") || "";
      return `\n\n\`\`\`mermaid\n${src}\n\`\`\`\n\n`;
    },
  });
  td.addRule("mdCallout", {
    filter: (node) => node.classList && node.classList.contains("md-callout"),
    replacement: (_content, node) => {
      const kind = node.getAttribute("data-callout") || "NOTE";
      const body = node.querySelector(".md-callout-body");
      const paras = body ? [...body.children].map((p) => td.turndown(p.innerHTML).trim()).filter(Boolean) : [];
      const lines = [`> [!${kind}]`].concat(paras.map((p) => `> ${p}`));
      return `\n\n${lines.join("\n>\n")}\n\n`;
    },
  });
  td.addRule("mdTask", {
    filter: (node) => node.nodeName === "LI" && node.classList && node.classList.contains("md-task"),
    replacement: (_content, node) => {
      const done = node.getAttribute("data-task") === "x";
      const textEl = node.querySelector(".md-task-text");
      const text = textEl ? td.turndown(textEl.innerHTML).trim() : "";
      return `- [${done ? "x" : " "}] ${text}\n`;
    },
  });
  td.addRule("mdImage", {
    filter: "img",
    replacement: (_content, node) => {
      const src = node.getAttribute("data-mdsrc") || node.getAttribute("src") || "";
      const alt = node.getAttribute("alt") || "";
      return `![${alt}](${src})`;
    },
  });
  td.addRule("mdStrikethrough", {
    filter: (node) => ["DEL", "S", "STRIKE"].includes(node.nodeName),
    replacement: (content) => `~~${content}~~`,
  });
  td.addRule("mdTable", {
    filter: (node) => node.nodeName === "TABLE",
    replacement: (_content, node) => {
      const rows = [...node.querySelectorAll("tr")];
      if (!rows.length) return "";
      const cellText = (tr) =>
        [...tr.children].map((c) => td.turndown(c.innerHTML).trim().replace(/\|/g, "\\|") || " ");
      const head = cellText(rows[0]);
      const lines = [`| ${head.join(" | ")} |`, `|${head.map(() => "---").join("|")}|`];
      rows.slice(1).forEach((tr) => lines.push(`| ${cellText(tr).join(" | ")} |`));
      return `\n\n${lines.join("\n")}\n\n`;
    },
  });

  function commitWysiwyg(force) {
    if (!state.lastEditedByUser && !force) return;
    const doc = document.getElementById("doc");
    if (!doc) return;
    const md = td.turndown(doc.innerHTML).trim() + "\n";
    state.markdown = md;
    state.lastEditedByUser = false;
    post("didEditMarkdown", md);
  }

  // ---------- find ----------
  function clearFindMarks() {
    const doc = document.getElementById("doc");
    if (!doc) return;
    doc.querySelectorAll("mark.find-m").forEach((m) => {
      const parent = m.parentNode;
      parent.replaceChild(document.createTextNode(m.textContent), m);
      parent.normalize();
    });
  }

  function applyFind() {
    clearFindMarks();
    state.findMatches = [];
    if (!state.findQuery) {
      post("findResult", { current: 0, total: 0 });
      return;
    }
    const doc = document.getElementById("doc");
    if (!doc) return;
    const query = state.findQuery.toLowerCase();
    const walker = document.createTreeWalker(doc, NodeFilter.SHOW_TEXT, {
      acceptNode: (n) => (n.parentElement && n.parentElement.closest("script,style") ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT),
    });
    const textNodes = [];
    let n;
    while ((n = walker.nextNode())) textNodes.push(n);
    textNodes.forEach((node) => {
      const text = node.textContent;
      const lower = text.toLowerCase();
      let start = 0;
      let idx;
      const pieces = [];
      let matched = false;
      while ((idx = lower.indexOf(query, start)) !== -1) {
        matched = true;
        pieces.push(document.createTextNode(text.slice(start, idx)));
        const mark = document.createElement("mark");
        mark.className = "find-m";
        mark.textContent = text.slice(idx, idx + query.length);
        pieces.push(mark);
        state.findMatches.push(mark);
        start = idx + query.length;
      }
      if (matched) {
        pieces.push(document.createTextNode(text.slice(start)));
        const frag = document.createDocumentFragment();
        pieces.forEach((p) => frag.appendChild(p));
        node.parentNode.replaceChild(frag, node);
      }
    });
    state.findIndex = 0;
    highlightCurrentMatch();
  }

  function highlightCurrentMatch() {
    state.findMatches.forEach((m) => m.classList.remove("find-cur"));
    const total = state.findMatches.length;
    if (total === 0) {
      post("findResult", { current: 0, total: 0 });
      return;
    }
    state.findIndex = ((state.findIndex % total) + total) % total;
    const cur = state.findMatches[state.findIndex];
    cur.classList.add("find-cur");
    cur.scrollIntoView({ block: "center", behavior: "smooth" });
    post("findResult", { current: state.findIndex + 1, total });
  }

  // ---------- task toggling (read mode) ----------
  // Flips the Nth task checkbox in the source. A targeted regex edit, never a
  // turndown round-trip, so nothing else in the document can be disturbed.
  function toggleTaskInMarkdown(md, index, checked) {
    let count = -1;
    return md.replace(/^(\s*(?:[-*+]|\d+\.)\s+)\[( |x|X)\]/gm, (match, prefix) => {
      count += 1;
      if (count !== index) return match;
      return prefix + "[" + (checked ? "x" : " ") + "]";
    });
  }

  // ---------- DOM event delegation ----------
  function onDocClick(e) {
    const copyBtn = e.target.closest && e.target.closest(".md-copy");
    if (copyBtn) {
      e.preventDefault();
      e.stopPropagation();
      const block = copyBtn.closest(".md-codeblock");
      const src = block ? block.getAttribute("data-src") || "" : "";
      if (navigator.clipboard) navigator.clipboard.writeText(src).catch(() => {});
      copyBtn.textContent = t().copied;
      copyBtn.classList.add("copied");
      setTimeout(() => {
        if (copyBtn.isConnected) {
          copyBtn.textContent = t().copy;
          copyBtn.classList.remove("copied");
        }
      }, 1300);
      return;
    }
    const check = e.target.closest && e.target.closest(".md-check");
    if (check) {
      e.preventDefault();
      const li = check.closest(".md-task");
      const done = li.getAttribute("data-task") === "x";
      li.setAttribute("data-task", done ? " " : "x");
      li.classList.toggle("md-task-done", !done);
      check.textContent = done ? "☐" : "☑";
      if (state.editing) {
        state.lastEditedByUser = true;
        commitWysiwyg(true);
      } else {
        // Read mode: flip the checkbox in the source directly (regex, not a
        // turndown round-trip) and hand the updated Markdown back to Swift.
        const doc = document.getElementById("doc");
        const idx = [...doc.querySelectorAll(".md-check")].indexOf(check);
        state.markdown = toggleTaskInMarkdown(state.markdown, idx, !done);
        post("didEditMarkdown", state.markdown);
      }
      return;
    }
    if (!state.editing) {
      const a = e.target.closest && e.target.closest("a");
      if (a) e.preventDefault();
    }
  }

  function applyAttrs() {
    const root = document.documentElement;
    root.setAttribute("data-theme", state.theme);
    root.setAttribute("data-rfont", state.rfont);
    root.setAttribute("data-mode", state.layout);
    root.setAttribute("data-editing", state.editing ? "true" : "false");
    document.getElementById("wrap").className = "md-doc-wrap";
  }

  // ---------- public bridge: window.raster ----------
  window.raster = {
    setContent(markdown) {
      state.markdown = markdown || "";
      render();
    },
    setTheme(theme) {
      state.theme = theme === "light" ? "light" : "dark";
      applyAttrs();
      if (mermaidReady) initMermaid();
      render();
    },
    setMode(mode) {
      state.editing = mode === "edit";
      const doc = document.getElementById("doc");
      if (doc) doc.setAttribute("contenteditable", state.editing ? "true" : "false");
      applyAttrs();
    },
    setReadingFont(font) {
      state.rfont = font === "sans" ? "sans" : "serif";
      applyAttrs();
    },
    setLanguage(lang) {
      state.lang = lang || "system";
      render();
    },
    setLayout(layout) {
      state.layout = layout === "reading" ? "reading" : "split";
      applyAttrs();
    },
    requestCommit() {
      commitWysiwyg(true);
    },
    find(query, direction) {
      if (direction === "reset") {
        state.findQuery = "";
        applyFind();
        return;
      }
      if (query !== undefined && query !== state.findQuery) {
        state.findQuery = query;
        applyFind();
        return;
      }
      if (direction === "next") {
        state.findIndex += 1;
        highlightCurrentMatch();
      } else if (direction === "prev") {
        state.findIndex -= 1;
        highlightCurrentMatch();
      }
    },
    scrollToHeading(id) {
      const doc = document.getElementById("doc");
      const scroller = document.getElementById("scroller");
      if (!doc || !scroller) return;
      const h = doc.querySelector("#" + CSS.escape(id));
      if (!h) return;
      const top = h.getBoundingClientRect().top - scroller.getBoundingClientRect().top + scroller.scrollTop;
      scroller.scrollTop = Math.max(0, top - 26);
    },
  };

  document.addEventListener("DOMContentLoaded", () => {
    initMermaid();
    applyAttrs();
    const doc = document.getElementById("doc");
    const scroller = document.getElementById("scroller");
    doc.addEventListener("click", onDocClick);
    doc.addEventListener("input", () => {
      state.lastEditedByUser = true;
    });
    doc.addEventListener("blur", () => commitWysiwyg(false));
    scroller.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("keydown", (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "s") {
        e.preventDefault();
        post("requestSave", null);
      }
    });
  });
})();
