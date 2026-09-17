public with sharing class ChatterFeedService {

    private static final Integer DEFAULT_PAGE_SIZE = 25;

    // ============================================================
    //  READ
    // ============================================================

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

    // ============================================================
    //  WRITE — POST
    // ============================================================

    public static ConnectApi.FeedElement postFeed(String recordId, String text, String feedElementType) {
        if (String.isBlank(recordId)) throw ChatterException.validation('recordId is required');
        if (String.isBlank(text))     throw ChatterException.validation('text is required');

        try {
            ConnectApi.FeedItemInput input = new ConnectApi.FeedItemInput();
            input.subjectId       = recordId;
            input.body            = ChatterFeedBodyHelper.buildRichBody(text);
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

    // ============================================================
    //  WRITE — UPDATE (with files)
    // ============================================================

    public static ConnectApi.FeedElement updateFeedElementWithFiles(
        String feedElementId,
        String text,
        List<String> newContentVersionIds
    ) {
        if (String.isBlank(feedElementId)) {
            throw ChatterException.validation('feedElementId is required');
        }

        try {
            ConnectApi.FeedItemInput input = new ConnectApi.FeedItemInput();
            input.body = ChatterFeedBodyHelper.buildRichBody(text);

            ConnectApi.FeedElement updated = ConnectApi.ChatterFeeds.updateFeedElement(
                ChatterCommunityContext.getCommunityId(),
                feedElementId,
                input
            );

            if (newContentVersionIds != null && !newContentVersionIds.isEmpty()) {
                List<String> errors = new List<String>();
                for (String cvId : newContentVersionIds) {
                    String err = ChatterFeedBodyHelper.tryLinkFile(feedElementId, cvId);
                    if (err != null) errors.add(err);
                }
                if (!errors.isEmpty()) {
                    System.debug(LoggingLevel.WARN,
                        'Some new files failed to attach: ' + String.join(errors, '; '));
                }
            }

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

    // ============================================================
    //  DELETE / LIKE / EDIT PERM
    // ============================================================

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

    private static Integer clampSize(Integer requested) {
        if (requested == null) return DEFAULT_PAGE_SIZE;
        if (requested < 1) return 1;
        if (requested > 100) return 100;
        return requested;
    }
}