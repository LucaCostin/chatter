export function reduceErrors(errors) {
    if (!errors) return 'Unknown error';
    if (!Array.isArray(errors)) errors = [errors];

    return errors
        .filter(err => err != null)
        .map(err => {
            if (typeof err === 'string') return err;
            if (Array.isArray(err.body)) return err.body.map(e => e.message).join(', ');
            if (err.body?.message) return err.body.message;
            if (err.message) return err.message;
            if (err.detail) return err.detail;
            if (err.statusText) return err.statusText;
            try { return JSON.stringify(err); } catch (e) { return String(err); }
        })
        .join(', ');
}

export function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

export function formatBytes(bytes) {
    if (!bytes && bytes !== 0) return '';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function relativeTime(iso) {
    if (!iso) return '';
    const d = new Date(iso);
    const diff = (Date.now() - d.getTime()) / 1000;
    if (diff < 60) return 'just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
    return d.toLocaleDateString();
}

// ============================================================
//  MENTION TOKEN HELPERS
// ============================================================
//
// Three representations of a mention fly through the system:
//
//   WIRE    "{005WU000019vmztYAA|razvan.luca}"   ← what the server sends
//   PILL    '<span class="mention-pill" data-id="005WU...">@razvan.luca</span>'
//   TOKEN   "{005WU000019vmztYAA}"                ← what ConnectApiHelper wants
//
// Conversions:
//   wireToPill      — server → editor (edit-load, display)
//   pillToToken     — editor → server (on save)
//   wireToLinks     — server → display-only anchors (feed render)

const MENTION_ID = '[a-zA-Z0-9]{15}|[a-zA-Z0-9]{18}';

export function wireTokensToComposerTokens(html) {
    if (!html) return '';
    const re = new RegExp(`\\{(${MENTION_ID})\\|([^}]+)\\}`, 'g');
    return html.replace(re, (match, id, name) => {
        const safeName = escapeHtml(name);
        const style = 'color:#047857;font-weight:600;text-decoration:none;background:#ecfdf5;padding:1px 6px;border-radius:6px;border:1px solid #a7f3d0;';
        return `<a href="/${id}" class="chatter-mention" style="${style}">@${safeName}</a>&nbsp;`;
    });
}

/**
 * Editor HTML → server wire format.
 * Handles two shapes:
 *   1. <span class="mention-pill" data-id="005...">...</span> → {005...}
 *   2. @{005...} → {005...}   (fallback if the pill got mangled)
 */
export function pillTokensToWire(html) {
    if (!html) return '';

    let out = html;

    // Anchor form: <a href="/005..." ...>@Name</a> → {005...}
    out = out.replace(
        new RegExp(`<a\\s+[^>]{0,500}href=["']\\/(${MENTION_ID})["'][^>]{0,500}>.*?<\\/a>`, 'gi'),
        (match, id) => `{${id}}`
    );
    // Fallback: @{005...} (in case the anchor got flattened)
    out = out.replace(new RegExp(`@\\{(${MENTION_ID})\\}`, 'g'), (match, id) => `{${id}}`);

    return out;
}

/**
 * Wire format → display anchors for the feed render path.
 * {005...|razvan.luca} → <a href="/005..." class="chatter-mention">@razvan.luca</a>
 */
export function mentionTokensToLinks(html) {
    if (!html) return '';
    const re = new RegExp(`\\{(${MENTION_ID})\\|([^}]+)\\}`, 'g');
    return html.replace(re, (match, id, name) => {
        const safeName = escapeHtml(name);
        return `<a href="/${id}" class="chatter-mention">@${safeName}</a>`;
    });
}

/**
 * Full normalize pipeline for composer output before sending to Apex.
 *  - Semantic → shorthand tags
 *  - Strip attributes on helper-recognized tags
 *  - Convert pills / @{id} → {id}
 *  - Clean up empty paragraphs
 */
export function normalizeRichTextHtml(html) {
    if (!html) return '';
    let out = html;

    // --- Step 1: convert mentions to wire tokens ---
    out = pillTokensToWire(out);

    // --- Step 2: semantic → shorthand ---
    out = out.replace(/<strong(\s[^>]*)?>/gi, '<b>');
    out = out.replace(/<\/strong>/gi, '</b>');
    out = out.replace(/<em(\s[^>]*)?>/gi, '<i>');
    out = out.replace(/<\/em>/gi, '</i>');
    out = out.replace(/<strike(\s[^>]*)?>/gi, '<s>');
    out = out.replace(/<\/strike>/gi, '</s>');
    out = out.replace(/<del(\s[^>]*)?>/gi, '<s>');
    out = out.replace(/<\/del>/gi, '</s>');

    // --- Step 3: strip attributes on helper-recognized tags ---
    out = out.replace(/<p(\s[^>]*)?>/gi, '<p>');
    out = out.replace(/<\/p(\s[^>]*)?>/gi, '</p>');
    out = out.replace(/<b(\s[^>]*)?>/gi, '<b>');
    out = out.replace(/<\/b(\s[^>]*)?>/gi, '</b>');
    out = out.replace(/<i(\s[^>]*)?>/gi, '<i>');
    out = out.replace(/<\/i(\s[^>]*)?>/gi, '</i>');
    out = out.replace(/<u(\s[^>]*)?>/gi, '<u>');
    out = out.replace(/<\/u(\s[^>]*)?>/gi, '</u>');
    out = out.replace(/<s(\s[^>]*)?>/gi, '<s>');
    out = out.replace(/<\/s(\s[^>]*)?>/gi, '</s>');
    out = out.replace(/<ul(\s[^>]*)?>/gi, '<ul>');
    out = out.replace(/<\/ul(\s[^>]*)?>/gi, '</ul>');
    out = out.replace(/<ol(\s[^>]*)?>/gi, '<ol>');
    out = out.replace(/<\/ol(\s[^>]*)?>/gi, '</ol>');
    out = out.replace(/<li(\s[^>]*)?>/gi, '<li>');
    out = out.replace(/<\/li(\s[^>]*)?>/gi, '</li>');
    out = out.replace(/<code(\s[^>]*)?>/gi, '<code>');
    out = out.replace(/<\/code(\s[^>]*)?>/gi, '</code>');

    // --- Step 4: strip wrapper tags but keep content ---
    out = out.replace(/<\/?(span|div|font|pre|section|article)(\s[^>]*)?>/gi, '');

    // --- Step 5: <br> → paragraph break ---
    out = out.replace(/<br\s*\/?>/gi, '</p><p>');

    // --- Step 6: headings → p ---
    out = out.replace(/<h[1-3](\s[^>]*)?>/gi, '<p>');
    out = out.replace(/<\/h[1-3]>/gi, '</p>');

    // --- Step 7: strip empty paragraphs ---
    out = out.replace(/<p>\s*<\/p>/gi, '');
    out = out.replace(/<p>&nbsp;<\/p>/gi, '');

    // --- Step 8: trim edges ---
    out = out.replace(/^<p><\/p>|<p><\/p>$/g, '');

    return out;
}