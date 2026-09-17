public with sharing class ChatterFeedService {

    private static final Integer DEFAULT_PAGE_SIZE = 25;

    public static ConnectApi.FeedElementPage getFeed(String recordId, String pageToken, Integer pageSize) {
        if (String.isBlank(recordId)) throw ChatterException.validation('recordId is required');
        Integer size = clampSize(pageSize);
        try {
            return ConnectApi.ChatterFeeds.getFeedElementsFromFeed(
                ChatterCommunityContext.getCommunityId(),
                ConnectApi.FeedType.Record,
                recordId,
                String.isBlank(pageToken) ? null : pageToken,
                size,
                ConnectApi.FeedSortOrder.LastModifiedDateDesc
            );
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static ConnectApi.FeedElementPage getNewsFeed(String pageToken, Integer pageSize) {
        Integer size = clampSize(pageSize);
        try {
            return ConnectApi.ChatterFeeds.getFeedElementsFromFeed(
                ChatterCommunityContext.getCommunityId(),
                ConnectApi.FeedType.News,
                null,
                String.isBlank(pageToken) ? null : pageToken,
                size,
                ConnectApi.FeedSortOrder.LastModifiedDateDesc
            );
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static ConnectApi.FeedElement postFeed(String recordId, String text, String feedElementType) {
        if (String.isBlank(recordId)) throw ChatterException.validation('recordId is required');
        if (String.isBlank(text))     throw ChatterException.validation('text is required');

        try {
            ConnectApi.FeedItemInput input = new ConnectApi.FeedItemInput();
            input.subjectId       = recordId;
            input.body            = buildRichBody(text);
            input.feedElementType = String.isNotBlank(feedElementType)
                ? ConnectApi.FeedElementType.valueOf(feedElementType)
                : ConnectApi.FeedElementType.FeedItem;

            return ConnectApi.ChatterFeeds.postFeedElement(
                ChatterCommunityContext.getCommunityId(), input
            );
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static ConnectApi.FeedElement updateFeedElement(String feedElementId, String text) {
        if (String.isBlank(feedElementId)) throw ChatterException.validation('feedElementId is required');
        if (String.isBlank(text))          throw ChatterException.validation('text is required');

        try {
            ConnectApi.FeedItemInput input = new ConnectApi.FeedItemInput();
            input.body = buildRichBody(text);

            ConnectApi.FeedElement updated = ConnectApi.ChatterFeeds.updateFeedElement(
                ChatterCommunityContext.getCommunityId(),
                feedElementId,
                input
            );

            try {
                ConnectApi.FeedElement full = ConnectApi.ChatterFeeds.getFeedElement(
                    ChatterCommunityContext.getCommunityId(),
                    feedElementId
                );
                if (full != null) return full;
            } catch (Exception ignored) {}

            return updated;
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static void deleteFeedElement(String feedElementId) {
        try {
            ConnectApi.ChatterFeeds.deleteFeedElement(
                ChatterCommunityContext.getCommunityId(), feedElementId
            );
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static String likeElement(String feedElementId) {
        try {
            ConnectApi.ChatterLike result = ConnectApi.ChatterFeeds.likeFeedElement(
                ChatterCommunityContext.getCommunityId(), feedElementId
            );
            return result == null ? null : result.id;
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static void unlikeElement(String likeId) {
        if (String.isBlank(likeId)) throw ChatterException.validation('likeId is required');
        try {
            ConnectApi.ChatterFeeds.deleteLike(
                ChatterCommunityContext.getCommunityId(), likeId
            );
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static Boolean canEditFeedElement(String feedElementId) {
        if (String.isBlank(feedElementId)) return false;
        try {
            ConnectApi.FeedEntityIsEditable result =
                ConnectApi.ChatterFeeds.isFeedElementEditableByMe(
                    ChatterCommunityContext.getCommunityId(),
                    feedElementId
                );
            return result != null && result.isEditableByMe == true;
        } catch (Exception e) {
            return false;
        }
    }

    // ============================================================
    //  HELPERS
    // ============================================================

    /**
     * Builds a MessageBodyInput from composer HTML using the
     * Salesforce ConnectApiHelper. Handles:
     *   <b> <i> <u> <s> <p> <ul> <ol> <li> <code>
     *   {005...}  — mention
     *   {img:069...} — inline image
     *   {record:01t...} — entity link
     */
    private static ConnectApi.MessageBodyInput buildRichBody(String html) {
        ConnectApi.MessageBodyInput body = new ConnectApi.MessageBodyInput();
        body.messageSegments = ConnectApiHelper.getMessageSegmentInputs(html);
        return body;
    }

    private static Integer clampSize(Integer requested) {
        if (requested == null) return DEFAULT_PAGE_SIZE;
        if (requested < 1) return 1;
        if (requested > 100) return 100;
        return requested;
    }

        /**
     * Updates a feed element's text and appends new file attachments.
     * Existing attachments are not modified — use deleteAttachment to remove them.
     * Returns the updated element mapped through the SOQL attachment reader,
     * so the caller sees all current files (old + new).
     */
    public static ConnectApi.FeedElement updateFeedElementWithFiles(
        String feedElementId,
        String text,
        List<String> newContentVersionIds
    ) {
        if (String.isBlank(feedElementId)) {
            throw ChatterException.validation('feedElementId is required');
        }

        try {
            // 1. Update the text body (if provided)
            ConnectApi.FeedItemInput input = new ConnectApi.FeedItemInput();
            input.body = buildRichBody(text);

            ConnectApi.FeedElement updated = ConnectApi.ChatterFeeds.updateFeedElement(
                ChatterCommunityContext.getCommunityId(),
                feedElementId,
                input
            );

            // 2. Attach any new files
            if (newContentVersionIds != null && !newContentVersionIds.isEmpty()) {
                List<String> errors = new List<String>();
                for (String cvId : newContentVersionIds) {
                    String err = tryLinkFile(feedElementId, cvId);
                    if (err != null) errors.add(err);
                }
                if (!errors.isEmpty()) {
                    System.debug(LoggingLevel.WARN,
                        'Some new files failed to attach: ' + String.join(errors, '; '));
                }
            }

            // 3. Re-fetch to get the latest state with all attachments
            try {
                ConnectApi.FeedElement full = ConnectApi.ChatterFeeds.getFeedElement(
                    ChatterCommunityContext.getCommunityId(),
                    feedElementId
                );
                if (full != null) return full;
            } catch (Exception ignored) {}

            return updated;

        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    private static String tryLinkFile(String feedElementId, String contentVersionId) {
        try {
            linkFileToFeedElement(feedElementId, contentVersionId);
            return null;
        } catch (Exception firstErr) {
            System.debug(LoggingLevel.WARN,
                'File link attempt 1 failed: ' + firstErr.getMessage());
        }
        try {
            linkFileToFeedElement(feedElementId, contentVersionId);
            return null;
        } catch (Exception secondErr) {
            System.debug(LoggingLevel.ERROR,
                'File link attempt 2 failed: ' + secondErr.getMessage());
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
}