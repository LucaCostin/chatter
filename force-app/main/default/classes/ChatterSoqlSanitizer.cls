public with sharing class ChatterSoqlSanitizer {

    private static final Pattern SAFE_IDENT =
        Pattern.compile('^[A-Za-z][A-Za-z0-9_]*$');
    private static final Pattern SAFE_FILTER_CHARS =
        Pattern.compile('^[A-Za-z0-9_\\s\\.\\(\\)\'\\-\\:\\+\\*/=<>!,]+$');
    private static final Pattern SAFE_ORDER_BY =
        Pattern.compile('^[A-Za-z][A-Za-z0-9_]*(\\s+(ASC|DESC))?(\\s*,\\s*[A-Za-z][A-Za-z0-9_]*(\\s+(ASC|DESC))?)*$');

    private static final Set<String> FORBIDDEN_KEYWORDS = new Set<String>{
        ';', '--', '/*', '*/',
        'LIMIT', 'OFFSET', 'UNION', 'SELECT', 'FROM',
        'INSERT', 'UPDATE', 'DELETE', 'UPSERT', 'MERGE',
        'EXEC', 'EXECUTE', 'SHARE', 'GRANT', 'REVOKE'
    };

    public static String identifier(String raw) {
        if (String.isBlank(raw)) return null;
        String t = raw.trim();
        if (!SAFE_IDENT.matcher(t).matches()) {
            throw ChatterException.security('Illegal identifier in metadata: ' + t);
        }
        return t;
    }

    public static String filter(String raw) {
        if (String.isBlank(raw)) return null;
        String t = raw.trim();
        String upper = t.toUpperCase();
        for (String kw : FORBIDDEN_KEYWORDS) {
            if (upper.contains(kw)) {
                throw ChatterException.security('Disallowed token in metadata filter: ' + kw);
            }
        }
        if (!SAFE_FILTER_CHARS.matcher(t).matches()) {
            throw ChatterException.security('Illegal characters in metadata filter');
        }
        return t;
    }

    public static String orderBy(String raw) {
        if (String.isBlank(raw)) return null;
        String t = raw.trim();
        if (!SAFE_ORDER_BY.matcher(t.toUpperCase()).matches()) {
            throw ChatterException.security('Illegal ORDER BY in metadata: ' + t);
        }
        return t;
    }

    public static Integer limitClamp(Decimal raw, Integer def, Integer minVal, Integer maxVal) {
        Integer v = raw == null ? def : Integer.valueOf(raw);
        if (v < minVal) v = minVal;
        if (v > maxVal) v = maxVal;
        return v;
    }
}