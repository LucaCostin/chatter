public with sharing class ChatterCommentService {

    private static final Integer DEFAULT_PAGE_SIZE = 25;

    public static ConnectApi.CommentPage getComments(String feedElementId, String pageToken, Integer pageSize) {
        if (String.isBlank(feedElementId)) throw ChatterException.validation('feedElementId is required');
        Integer size = clampSize(pageSize);
        try {
            return ConnectApi.ChatterFeeds.getCommentsForFeedElement(
                ChatterCommunityContext.getCommunityId(),
                feedElementId,
                String.isBlank(pageToken) ? null : pageToken,
                size
            );
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static ConnectApi.Comment postComment(String feedElementId, String text) {
        if (String.isBlank(feedElementId)) throw ChatterException.validation('feedElementId is required');
        if (String.isBlank(text))          throw ChatterException.validation('text is required');

        try {
            ConnectApi.CommentInput input = new ConnectApi.CommentInput();
            input.body = buildRichBody(text);

            return ConnectApi.ChatterFeeds.postCommentToFeedElement(
                ChatterCommunityContext.getCommunityId(),
                feedElementId,
                input,
                null
            );
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static ConnectApi.Comment updateComment(String commentId, String text) {
        if (String.isBlank(commentId)) throw ChatterException.validation('commentId is required');
        if (String.isBlank(text))      throw ChatterException.validation('text is required');

        try {
            ConnectApi.CommentInput input = new ConnectApi.CommentInput();
            input.body = buildRichBody(text);

            return ConnectApi.ChatterFeeds.updateComment(
                ChatterCommunityContext.getCommunityId(),
                commentId,
                input
            );
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static ConnectApi.Comment updateCommentWithFiles(
        String commentId,
        String text,
        List<String> newContentVersionIds
    ) {
        if (String.isBlank(commentId)) {
            throw ChatterException.validation('commentId is required');
        }

        try {
            ConnectApi.CommentInput input = new ConnectApi.CommentInput();
            input.body = buildRichBody(text);

            ConnectApi.Comment updated = ConnectApi.ChatterFeeds.updateComment(
                ChatterCommunityContext.getCommunityId(),
                commentId,
                input
            );

            if (newContentVersionIds != null && !newContentVersionIds.isEmpty()) {
                for (String cvId : newContentVersionIds) {
                    try {
                        linkFileToFeedElement(commentId, cvId);
                    } catch (Exception e) {
                        System.debug(LoggingLevel.WARN,
                            'Comment file attach failed: ' + e.getMessage());
                    }
                }
            }

            return updated;

        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
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

    public static void deleteComment(String commentId) {
        if (String.isBlank(commentId)) throw ChatterException.validation('commentId is required');
        try {
            ConnectApi.ChatterFeeds.deleteComment(
                ChatterCommunityContext.getCommunityId(), commentId
            );
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static String likeComment(String commentId) {
        try {
            ConnectApi.ChatterLike result = ConnectApi.ChatterFeeds.likeComment(
                ChatterCommunityContext.getCommunityId(), commentId
            );
            return result == null ? null : result.id;
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static void unlikeComment(String likeId) {
        if (String.isBlank(likeId)) throw ChatterException.validation('likeId is required');
        try {
            ConnectApi.ChatterFeeds.deleteLike(
                ChatterCommunityContext.getCommunityId(), likeId
            );
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    public static Boolean canEditComment(String commentId) {
        if (String.isBlank(commentId)) return false;
        try {
            ConnectApi.FeedEntityIsEditable result =
                ConnectApi.ChatterFeeds.isCommentEditableByMe(
                    ChatterCommunityContext.getCommunityId(),
                    commentId
                );
            return result != null && result.isEditableByMe == true;
        } catch (Exception e) {
            return false;
        }
    }

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
}