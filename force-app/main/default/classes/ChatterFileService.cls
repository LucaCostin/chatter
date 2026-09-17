public with sharing class ChatterFileService {

    private static final Integer MAX_FILES_PER_POST = 10;
    private static final Integer MAX_FILE_BYTES = 5242880;   // 5 MB
    private static final Set<String> BLOCKED_MIMES = new Set<String>{
        'text/html',
        'application/xhtml+xml',
        'application/javascript',
        'text/javascript',
        'application/x-javascript',
        'image/svg+xml',
        'application/x-httpd-php',
        'application/x-sh',
        'application/x-msdownload'
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

        if (String.isNotBlank(mimeType) && BLOCKED_MIMES.contains(mimeType.toLowerCase())) {
            throw ChatterException.validation('File type not permitted: ' + mimeType);
        }

        Blob decoded;
        try {
            decoded = EncodingUtil.base64Decode(base64Data);
        } catch (Exception e) {
            throw ChatterException.validation('Invalid file data');
        }
        if (decoded.size() > MAX_FILE_BYTES) {
            throw ChatterException.validation('File exceeds 5 MB limit');
        }

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