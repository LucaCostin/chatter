public with sharing class ChatterHtmlSanitizer {

    public static String stripTags(String html) {
        if (String.isBlank(html)) return '';

        String out = html;

        // Drop empty paragraph / div / span tags FIRST — before they become newlines
        out = out.replaceAll('(?i)<(p|div|span|h[1-6]|li)[^>]*>\\s*</\\1>', '');

        // Block-level tags → newline so paragraphs don't run together
        out = out.replaceAll('(?i)<\\s*/?\\s*(p|div|br|li|h[1-6]|tr)[^>]*>', '\n');

        // Everything else → drop
        out = out.replaceAll('<[^>]*>', '');

        // Common entities
        out = out.replace('&nbsp;',  ' ');
        out = out.replace('&amp;',   '&');
        out = out.replace('&lt;',    '<');
        out = out.replace('&gt;',    '>');
        out = out.replace('&quot;',  '"');
        out = out.replace('&#39;',   '\'');
        out = out.replace('&#x27;',  '\'');

        // Numeric entities — best effort
        out = out.replaceAll('&#(\\d+);', ' ');

        // Collapse whitespace-only lines
        out = out.replaceAll('(?m)^[ \\t]+$', '');

        // Collapse 3+ newlines down to 2
        out = out.replaceAll('\\n{3,}', '\n\n');

        // Trim leading/trailing blank lines
        out = out.replaceAll('^\\n+', '');
        out = out.replaceAll('\\n+$', '');

        return out.trim();
    }
}