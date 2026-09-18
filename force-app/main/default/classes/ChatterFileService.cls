public with sharing class ChatterFileService {

    private static final Integer MAX_FILES_PER_POST = 10;
    private static final Integer MAX_FILE_BYTES = 5242880;   // 5 MB

    /**
     * MIME types permitted for upload.
     *
     * This is an ALLOWLIST. Anything not listed is rejected.
     *
     * Deliberately excluded:
     *   - text/html, application/xhtml+xml (XSS)
     *   - application/javascript, text/javascript (XSS)
     *   - image/svg+xml (XSS via embedded scripts)
     *   - application/xml, text/xml (billion laughs / XXE)
     *   - .exe, .bat, .sh, .ps1, .msi (executables)
     *   - .jar, .app, .dmg (bundles)
     */
    private static final Set<String> ALLOWED_MIMES = new Set<String>{
        // ---- Images (raster only — SVG excluded) ----
        'image/jpeg',
        'image/jpg',
        'image/png',
        'image/gif',
        'image/webp',
        'image/bmp',
        'image/tiff',
        'image/heic',
        'image/heif',

        // ---- Documents ----
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'application/vnd.oasis.opendocument.text',
        'application/vnd.oasis.opendocument.spreadsheet',
        'application/vnd.oasis.opendocument.presentation',
        'application/vnd.apple.pages',
        'application/vnd.apple.numbers',
        'application/vnd.apple.keynote',

        // ---- Plain text only ----
        'text/plain',
        'text/csv',
        'text/markdown',

        // ---- Archives ----
        'application/zip',
        'application/x-zip-compressed',
        'application/x-rar-compressed',
        'application/vnd.rar',
        'application/x-7z-compressed',
        'application/x-tar',
        'application/gzip',

        // ---- Audio ----
        'audio/mpeg',
        'audio/mp3',
        'audio/wav',
        'audio/x-wav',
        'audio/ogg',
        'audio/mp4',
        'audio/aac',

        // ---- Video ----
        'video/mp4',
        'video/quicktime',
        'video/x-msvideo',
        'video/webm',
        'video/ogg'
    };

    // ============================================================
    //  POST FEED ELEMENT + FILES
    // ============================================================

    public static ChatterPostResultDto postFeedWithFiles(
        String recordId,
        String text,
        List<String> contentVersionIds
    ) {
        if (String.isBlank(recordId)) {
            throw ChatterException.validation('recordId is required');
        }

        ChatterPostResultDto result = new ChatterPostResultDto();
        List<String> capped = ChatterFeedBodyHelper.capList(contentVersionIds, MAX_FILES_PER_POST);

        try {
            ConnectApi.FeedItemInput input = new ConnectApi.FeedItemInput();
            input.subjectId       = recordId;
            input.body            = ChatterFeedBodyHelper.buildRichBody(text);
            input.feedElementType = ConnectApi.FeedElementType.FeedItem;

            ConnectApi.FeedElement el = ConnectApi.ChatterFeeds.postFeedElement(
                ChatterCommunityContext.getCommunityId(), input
            );

            if (!capped.isEmpty()) {
                List<String> errors = new List<String>();
                for (String cvId : capped) {
                    String err = ChatterFeedBodyHelper.tryLinkFile(el.id, cvId);
                    if (err != null) errors.add(err);
                }
                if (!errors.isEmpty()) {
                    result.attachmentError = String.join(errors, '; ');
                }
            }

            result.element = ChatterDtoMapper.toFeedElement(el);
            return result;

        } catch (ChatterException ce) {
            throw ce;
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    // ============================================================
    //  UPLOAD / DELETE
    // ============================================================

    @AuraEnabled
    public static String uploadFile(String filename, String base64Data, String mimeType) {
        if (String.isBlank(filename))   throw ChatterException.validation('filename is required');
        if (String.isBlank(base64Data)) throw ChatterException.validation('base64Data is required');

        // ---- MIME allowlist check ----
        // Normalize: strip charset suffix, lowercase, trim
        // Example: "text/plain; charset=utf-8" → "text/plain"
        String normalizedMime = '';
        if (String.isNotBlank(mimeType)) {
            normalizedMime = mimeType.toLowerCase().split(';')[0].trim();
        }

        if (String.isBlank(normalizedMime)) {
            throw ChatterException.validation(
                'File type could not be determined. Please upload a file with a recognized type.'
            );
        }

        if (!ALLOWED_MIMES.contains(normalizedMime)) {
            throw ChatterException.validation(
                'File type not permitted: ' + normalizedMime
            );
        }

        // ---- Size check ----
        Blob decoded;
        try {
            decoded = EncodingUtil.base64Decode(base64Data);
        } catch (Exception e) {
            throw ChatterException.validation('Invalid file data');
        }
        if (decoded.size() > MAX_FILE_BYTES) {
            throw ChatterException.validation('File exceeds 5 MB limit');
        }

        // ---- Filename sanitization ----
        String safeName = sanitizeFilename(filename);
        if (String.isBlank(safeName)) {
            throw ChatterException.validation('Invalid filename');
        }

        try {
            ContentVersion cv = new ContentVersion();
            cv.Title          = stripExtension(safeName);
            cv.PathOnClient   = safeName;
            cv.VersionData    = decoded;
            cv.IsMajorVersion = true;
            insert cv;
            return cv.Id;
        } catch (DmlException de) {
            throw ChatterException.validation('Upload failed: ' + de.getDmlMessage(0));
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    @AuraEnabled
    public static void deleteAttachment(String contentVersionId) {
        if (String.isBlank(contentVersionId)) {
            throw ChatterException.validation('contentVersionId is required');
        }

        List<FeedAttachment> rows = [
            SELECT Id, FeedEntityId
            FROM FeedAttachment
            WHERE RecordId = :contentVersionId AND Type = 'Content'
        ];
        if (rows.isEmpty()) return;

        String parentFeedElementId = rows[0].FeedEntityId;
        if (!ChatterFeedService.canEditFeedElement(parentFeedElementId)) {
            throw ChatterException.security(
                'Not permitted to modify attachments on this post'
            );
        }

        delete rows;
    }

    // ============================================================
    //  PRIVATE
    // ============================================================

    private static String sanitizeFilename(String name) {
        if (String.isBlank(name)) return null;
        String s = name.replaceAll('[\\\\/:*?"<>|\\x00-\\x1F]', '_');
        s = s.trim();
        if (s.length() > 200) s = s.substring(0, 200);
        return s;
    }

    private static String stripExtension(String filename) {
        Integer dot = filename.lastIndexOf('.');
        return dot > 0 ? filename.substring(0, dot) : filename;
    }
}