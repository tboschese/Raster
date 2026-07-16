// strings.js — preview UI label dictionary (en / pt-BR).
// Scope: only strings the WebCore renders itself (callouts, code buttons, the
// WYSIWYG banner, Mermaid errors, empty states, find placeholder). Everything
// else — menus, dialogs, the toolbar — lives in the native String Catalog and
// is never duplicated here. User content is never translated.

window.RasterStrings = {
  en: {
    callouts: { NOTE: "Note", TIP: "Tip", WARNING: "Warning", IMPORTANT: "Important", CAUTION: "Caution" },
    copy: "copy",
    copied: "copied",
    banner: "editing — code and diagrams locked",
    mermaidError: "Diagram error",
    noHeadings: "No headings.",
    findPlaceholder: "Find in document",
  },
  "pt-BR": {
    callouts: { NOTE: "Nota", TIP: "Dica", WARNING: "Atenção", IMPORTANT: "Importante", CAUTION: "Cuidado" },
    copy: "copiar",
    copied: "copiado",
    banner: "editando — código e diagramas travados",
    mermaidError: "Erro no diagrama",
    noHeadings: "Sem títulos.",
    findPlaceholder: "Buscar no documento",
  },
};

window.RasterStrings.resolve = function (lang) {
  return window.RasterStrings[lang] || window.RasterStrings.en;
};
