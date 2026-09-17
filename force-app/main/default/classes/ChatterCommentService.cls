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

    public static ChatterPostResultDto postCommentWithFiles(
        String feedElementId,
        String text,
        List<String> contentVersionIds
    ) {
        if (String.isBlank(feedElementId)) {
            throw ChatterException.validation('feedElementId is required');
        }

        ChatterPostResultDto result = new ChatterPostResultDto();
        List<String> capped = ChatterFeedBodyHelper.capList(contentVersionIds, 1);   // 1 file max per comment

        try {
            ConnectApi.CommentInput input = new ConnectApi.CommentInput();
            input.body = ChatterFeedBodyHelper.buildRichBody(text);

            if (!capped.isEmpty()) {
                String contentDocumentId = translateToContentDocumentId(capped[0]);
                if (String.isNotBlank(contentDocumentId)) {
                    ConnectApi.ContentCapabilityInput cc = new ConnectApi.ContentCapabilityInput();
                    cc.contentDocumentId = contentDocumentId;

                    ConnectApi.CommentCapabilitiesInput caps = new ConnectApi.CommentCapabilitiesInput();
                    caps.content = cc;

                    input.capabilities = caps;
                }
            }

            ConnectApi.Comment c = ConnectApi.ChatterFeeds.postCommentToFeedElement(
                ChatterCommunityContext.getCommunityId(),
                feedElementId,
                input,
                null
            );

            result.comment = ChatterDtoMapper.toComment(c);
            return result;

        } catch (ChatterException ce) {
            throw ce;
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    /**
     * Updates a comment's text.
     *
     * NOTE: Comment capabilities (including files) cannot be updated after
     * creation. The Connect API throws "Comment capabilities cannot be
     * updated" for any attempt. Standard Chatter UI has the same limitation.
     *
     * New files passed here are rejected explicitly to surface the issue
     * rather than silently dropping them.
     */
    public static ChatterPostResultDto updateCommentWithFiles(
        String commentId,
        String text,
        List<String> newContentVersionIds
    ) {
        if (String.isBlank(commentId)) {
            throw ChatterException.validation('commentId is required');
        }

        if (newContentVersionIds != null && !newContentVersionIds.isEmpty()) {
            throw ChatterException.validation(
                'Comment files can\'t be changed after posting. Delete and re-post the comment to attach a different file.'
            );
        }

        ChatterPostResultDto result = new ChatterPostResultDto();

        try {
            ConnectApi.CommentInput input = new ConnectApi.CommentInput();
            input.body = ChatterFeedBodyHelper.buildRichBody(text);

            ConnectApi.Comment updated = ConnectApi.ChatterFeeds.updateComment(
                ChatterCommunityContext.getCommunityId(),
                commentId,
                input
            );

            result.comment = ChatterDtoMapper.toComment(updated);
            return result;

        } catch (ChatterException ce) {
            throw ce;
        } catch (Exception e) {
            throw ChatterException.fromConnect(e);
        }
    }

    private static String translateToContentDocumentId(String contentVersionId) {
        if (String.isBlank(contentVersionId)) return null;
        List<ContentVersion> cvs = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1
        ];
        return cvs.isEmpty() ? null : cvs[0].ContentDocumentId;
    }

    private static Integer clampSize(Integer requested) {
        if (requested == null) return DEFAULT_PAGE_SIZE;
        if (requested < 1) return 1;
        if (requested > 100) return 100;
        return requested;
    }
}