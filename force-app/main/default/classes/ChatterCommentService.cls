public with sharing class ChatterCommentService {

    private static final Integer DEFAULT_PAGE_SIZE = 25;

    // ============================================================
    //  READ
    // ============================================================

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

    // ============================================================
    //  WRITE — POST
    // ============================================================

    public static ConnectApi.Comment postComment(String feedElementId, String text) {
        if (String.isBlank(feedElementId)) throw ChatterException.validation('feedElementId is required');
        if (String.isBlank(text))          throw ChatterException.validation('text is required');

        try {
            ConnectApi.CommentInput input = new ConnectApi.CommentInput();
            input.body = ChatterFeedBodyHelper.buildRichBody(text);

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

    // ============================================================
    //  WRITE — UPDATE
    // ============================================================

    public static ConnectApi.Comment updateComment(String commentId, String text) {
        if (String.isBlank(commentId)) throw ChatterException.validation('commentId is required');
        if (String.isBlank(text))      throw ChatterException.validation('text is required');

        try {
            ConnectApi.CommentInput input = new ConnectApi.CommentInput();
            input.body = ChatterFeedBodyHelper.buildRichBody(text);

            return ConnectApi.ChatterFeeds.updateComment(
                ChatterCommunityContext.getCommunityId(),
                commentId,
                input
            );
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    // ============================================================
    //  DELETE / LIKE / EDIT PERM
    // ============================================================

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