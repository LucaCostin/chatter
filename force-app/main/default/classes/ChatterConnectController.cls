public with sharing class ChatterConnectController {

    // ============================================================
    //  RAIL / CONFIG
    // ============================================================

    @AuraEnabled(cacheable=true)
    public static List<ChatterConfigDto> getConfigs() {
        return ChatterConfigService.getConfigs();
    }

    @AuraEnabled(cacheable=true)
    public static List<ChatterRecordDto> getRecordsForConfig(String configDeveloperName) {
        return ChatterConfigService.getRecordsForConfig(configDeveloperName);
    }

    // ============================================================
    //  FEED — READ
    // ============================================================

    @AuraEnabled
    public static ChatterFeedPageDto getFeed(String recordId, String pageToken, Integer pageSize) {
        return ChatterDtoMapper.toFeedPage(ChatterFeedService.getFeed(recordId, pageToken, pageSize));
    }

    @AuraEnabled
    public static ChatterFeedPageDto getNewsFeed(String pageToken, Integer pageSize) {
        return ChatterDtoMapper.toFeedPage(ChatterFeedService.getNewsFeed(pageToken, pageSize));
    }

    // ============================================================
    //  FEED — WRITE
    // ============================================================

    @AuraEnabled
    public static ChatterFeedElementDto postFeed(String recordId, String text, String feedElementType) {
        return ChatterDtoMapper.toFeedElement(ChatterFeedService.postFeed(recordId, text, feedElementType));
    }

    @AuraEnabled
    public static ChatterPostResultDto postFeedWithFiles(
        String recordId,
        String text,
        List<String> contentVersionIds
    ) {
        return ChatterFileService.postFeedWithFiles(recordId, text, contentVersionIds);
    }

    @AuraEnabled
    public static ChatterFeedElementDto updateFeedWithFiles(
        String feedElementId,
        String text,
        List<String> newContentVersionIds
    ) {
        return ChatterDtoMapper.toFeedElement(
            ChatterFeedService.updateFeedElementWithFiles(feedElementId, text, newContentVersionIds)
        );
    }

    @AuraEnabled
    public static void deleteFeedElement(String feedElementId) {
        ChatterFeedService.deleteFeedElement(feedElementId);
    }

    // ============================================================
    //  LIKES
    // ============================================================

    @AuraEnabled public static String likeFeedElement(String feedElementId) { return ChatterFeedService.likeElement(feedElementId); }
    @AuraEnabled public static void   unlikeFeedElement(String likeId)       { ChatterFeedService.unlikeElement(likeId); }
    @AuraEnabled public static String likeComment(String commentId)          { return ChatterCommentService.likeComment(commentId); }
    @AuraEnabled public static void   unlikeComment(String likeId)           { ChatterCommentService.unlikeComment(likeId); }

    // ============================================================
    //  COMMENTS
    // ============================================================

    @AuraEnabled
    public static ChatterCommentPageDto getComments(String feedElementId, String pageToken, Integer pageSize) {
        return ChatterDtoMapper.toCommentPage(
            ChatterCommentService.getComments(feedElementId, pageToken, pageSize)
        );
    }

    @AuraEnabled
    public static ChatterCommentDto postComment(String feedElementId, String text) {
        return ChatterDtoMapper.toComment(
            ChatterCommentService.postComment(feedElementId, text)
        );
    }

    @AuraEnabled
    public static ChatterCommentDto updateComment(String commentId, String text) {
        return ChatterDtoMapper.toComment(
            ChatterCommentService.updateComment(commentId, text)
        );
    }

    @AuraEnabled
    public static void deleteComment(String commentId) {
        ChatterCommentService.deleteComment(commentId);
    }

    // ============================================================
    //  FILES
    // ============================================================

    @AuraEnabled
    public static String uploadFile(String filename, String base64Data, String mimeType) {
        return ChatterFileService.uploadFile(filename, base64Data, mimeType);
    }

    @AuraEnabled
    public static void deleteAttachment(String contentVersionId) {
        ChatterFileService.deleteAttachment(contentVersionId);
    }

    // ============================================================
    //  ENRICHMENT (batch, capped)
    // ============================================================

    @AuraEnabled
    public static List<ChatterCommentDto> getCommentEnrichment(List<String> commentIds) {
        if (commentIds == null || commentIds.isEmpty()) return new List<ChatterCommentDto>();
        if (commentIds.size() > 50) commentIds = cap(commentIds, 50);
        return ChatterDtoMapper.enrichComments(commentIds);
    }

    @AuraEnabled
    public static Map<String, Boolean> getFeedEditPermissions(List<String> feedElementIds) {
        if (feedElementIds == null || feedElementIds.isEmpty()) return new Map<String, Boolean>();
        if (feedElementIds.size() > 50) feedElementIds = cap(feedElementIds, 50);
        return ChatterDtoMapper.enrichFeedEditPermissions(feedElementIds);
    }

    // ============================================================
    //  MENTIONS / USER
    // ============================================================

    @AuraEnabled(cacheable=true)
    public static List<ChatterMentionDto> searchMentions(String term, Integer limitSize) {
        return ChatterMentionService.search(term, limitSize);
    }

    @AuraEnabled(cacheable=true)
    public static User getCurrentUser() {
        return [
            SELECT Id, Name, SmallPhotoUrl, FullPhotoUrl, Title
            FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
        ];
    }

    // ============================================================
    //  PRIVATE
    // ============================================================

    private static List<String> cap(List<String> source, Integer max) {
        List<String> out = new List<String>();
        for (Integer i = 0; i < max; i++) out.add(source[i]);
        return out;
    }
}