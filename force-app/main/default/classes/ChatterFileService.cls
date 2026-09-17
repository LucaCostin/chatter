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
        List<String> capped = capList(contentVersionIds, MAX_FILES_PER_POST);

        try {
            // 1. Post the feed element with rich body
            ConnectApi.FeedItemInput input = new ConnectApi.FeedItemInput();
            input.subjectId       = recordId;
            input.body            = buildRichBody(text);
            input.feedElementType = ConnectApi.FeedElementType.FeedItem;

            ConnectApi.FeedElement el = ConnectApi.ChatterFeeds.postFeedElement(
                ChatterCommunityContext.getCommunityId(), input
            );

            // 2. Attach files one at a time
            if (!capped.isEmpty()) {
                List<String> errors = new List<String>();
                for (String cvId : capped) {
                    String err = tryLinkFile(el.id, cvId);
                    if (err != null) errors.add(err);
                }
                if (!errors.isEmpty()) {
                    result.attachmentError = String.join(errors, '; ');
                }
            }

            // 3. Map — reads attachments via SOQL, includes all successfully linked
            result.element = ChatterDtoMapper.toFeedElement(el);
            return result;

        } catch (ChatterException ce) {
            throw ce;
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static ChatterPostResultDto postCommentWithFiles(
        String feedElementId,
        String text,
        List<String> contentVersionIds
    ) {
        if (String.isBlank(feedElementId)) {
            throw ChatterException.validation('feedElementId is required');
        }

        ChatterPostResultDto result = new ChatterPostResultDto();
        List<String> capped = capList(contentVersionIds, MAX_FILES_PER_POST);

        try {
            ConnectApi.CommentInput input = new ConnectApi.CommentInput();
            input.body = buildRichBody(text);

            ConnectApi.Comment c = ConnectApi.ChatterFeeds.postCommentToFeedElement(
                ChatterCommunityContext.getCommunityId(),
                feedElementId,
                input,
                null
            );

            if (!capped.isEmpty()) {
                List<String> errors = new List<String>();
                for (String cvId : capped) {
                    String err = tryLinkFile(c.id, cvId);
                    if (err != null) errors.add(err);
                }
                if (!errors.isEmpty()) {
                    result.attachmentError = String.join(errors, '; ');
                }
            }

            result.comment = ChatterDtoMapper.toComment(c);
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

    @AuraEnabled(cacheable=true)
    public static ChatterAttachmentDto getAttachmentInfo(String contentDocumentId) {
        if (String.isBlank(contentDocumentId)) {
            throw ChatterException.validation('contentDocumentId is required');
        }
        List<ContentVersion> cvs = [
            SELECT Id, ContentDocumentId, Title, FileExtension, FileType, ContentSize
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true
            LIMIT 1
        ];
        if (cvs.isEmpty()) throw ChatterException.notFound('ContentDocument not found: ' + contentDocumentId);
        ContentVersion cv = cvs[0];
        ChatterAttachmentDto d = new ChatterAttachmentDto();
        d.id               = cv.ContentDocumentId;
        d.contentVersionId = cv.Id;
        d.title            = cv.Title;
        d.fileExtension    = cv.FileExtension;
        d.fileSize         = cv.ContentSize == null ? null : Integer.valueOf(cv.ContentSize);
        d.mimeType         = cv.FileType;
        d.url              = '/sfsites/c/sfc/servlet.shepherd/document/download/' + cv.ContentDocumentId;
        return d;
    }

    // ============================================================
    //  PRIVATE
    // ============================================================

    private static ConnectApi.MessageBodyInput buildRichBody(String html) {
        ConnectApi.MessageBodyInput body = new ConnectApi.MessageBodyInput();
        if (String.isBlank(html)) {
            ConnectApi.TextSegmentInput seg = new ConnectApi.TextSegmentInput();
            seg.text = '';
            body.messageSegments = new List<ConnectApi.MessageSegmentInput>{ seg };
        } else {
            body.messageSegments = ConnectApiHelper.getMessageSegmentInputs(html);
        }
        return body;
    }

    private static List<String> capList(List<String> source, Integer max) {
        if (source == null) return new List<String>();
        if (source.size() <= max) return source;
        List<String> out = new List<String>();
        for (Integer i = 0; i < max; i++) out.add(source[i]);
        return out;
    }

    private static String tryLinkFile(String feedElementId, String contentVersionId) {
        // Attempt 1
        try {
            linkFileToFeedElement(feedElementId, contentVersionId);
            return null;
        } catch (Exception firstErr) {
            System.debug(LoggingLevel.WARN,
                'File link attempt 1 failed for ' + feedElementId + ': ' + firstErr.getMessage());
        }
        // Attempt 2
        try {
            linkFileToFeedElement(feedElementId, contentVersionId);
            return null;
        } catch (Exception secondErr) {
            System.debug(LoggingLevel.ERROR,
                'File link attempt 2 failed for ' + feedElementId + ': ' + secondErr.getMessage());
            return secondErr.getMessage();
        }
    }

    private static void linkFileToFeedElement(String feedElementId, String contentVersionId) {
        List<FeedAttachment> existing = [
            SELECT Id FROM FeedAttachment
            WHERE FeedEntityId = :feedElementId AND RecordId = :contentVersionId
            LIMIT 1
        ];
        if (!existing.isEmpty()) return;

        FeedAttachment fa = new FeedAttachment();
        fa.FeedEntityId = feedElementId;
        fa.RecordId     = contentVersionId;
        fa.Type         = 'Content';
        insert fa;
    }

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