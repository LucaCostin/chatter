/**
 * Shared helpers for constructing Connect API message bodies and
 * linking files to feed elements. Consolidates code that was previously
 * duplicated across ChatterFeedService, ChatterCommentService, and
 * ChatterFileService.
 */
public with sharing class ChatterFeedBodyHelper {

    /**
     * Builds a rich-body MessageBodyInput from composer HTML.
     * Routes through ConnectApiHelper so markup segments, mentions, and
     * inline images are stored correctly.
     */
    public static ConnectApi.MessageBodyInput buildRichBody(String html) {
        ConnectApi.MessageBodyInput body = new ConnectApi.MessageBodyInput();

        if (String.isBlank(html)) {
            ConnectApi.TextSegmentInput seg = new ConnectApi.TextSegmentInput();
            seg.text = '';
            body.messageSegments = new List<ConnectApi.MessageSegmentInput>{ seg };
            return body;
        }

        body.messageSegments = ConnectApiHelper.getMessageSegmentInputs(html);
        return body;
    }

    /**
     * Attempts to link a ContentVersion to a feed element.
     * Retries once on failure (transient DML or indexing races).
     * Returns null on success, error message string on failure.
     */
    public static String tryLinkFile(String feedElementId, String contentVersionId) {
        try {
            linkFileToFeedElement(feedElementId, contentVersionId);
            return null;
        } catch (Exception firstErr) {
            System.debug(LoggingLevel.WARN,
                'File link attempt 1 failed for ' + feedElementId + ': ' + firstErr.getMessage());
        }
        try {
            linkFileToFeedElement(feedElementId, contentVersionId);
            return null;
        } catch (Exception secondErr) {
            System.debug(LoggingLevel.ERROR,
                'File link attempt 2 failed for ' + feedElementId + ': ' + secondErr.getMessage());
            return secondErr.getMessage();
        }
    }

    /**
     * Idempotent insert of a FeedAttachment link.
     */
    public static void linkFileToFeedElement(String feedElementId, String contentVersionId) {
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

    /**
     * Caps a list at max items.
     */
    public static List<String> capList(List<String> source, Integer max) {
        if (source == null) return new List<String>();
        if (source.size() <= max) return source;
        List<String> out = new List<String>();
        for (Integer i = 0; i < max; i++) out.add(source[i]);
        return out;
    }
}