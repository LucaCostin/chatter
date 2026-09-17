public with sharing class ChatterConnectController {

    // RAIL / CONFIG (cacheable is fine — metadata rarely changes)
    @AuraEnabled(cacheable=true)
    public static List<ChatterConfigDto> getConfigs() { return ChatterConfigService.getConfigs(); }

    @AuraEnabled(cacheable=true)
    public static List<ChatterRecordDto> getRecordsForConfig(String configDeveloperName) {
        return ChatterConfigService.getRecordsForConfig(configDeveloperName);
    }

    // FEED — READ (not cacheable — refresh must hit the server)
    @AuraEnabled
    public static ChatterFeedPageDto getFeed(String recordId, String pageToken, Integer pageSize) {
        return ChatterDtoMapper.toFeedPage(ChatterFeedService.getFeed(recordId, pageToken, pageSize));
    }

    @AuraEnabled
    public static ChatterFeedPageDto getNewsFeed(String pageToken, Integer pageSize) {
        return ChatterDtoMapper.toFeedPage(ChatterFeedService.getNewsFeed(pageToken, pageSize));
    }

    // FEED — WRITE
    @AuraEnabled
    public static ChatterFeedElementDto postFeed(String recordId, String text, String feedElementType) {
        return ChatterDtoMapper.toFeedElement(ChatterFeedService.postFeed(recordId, text, feedElementType));
    }

    @AuraEnabled
    public static ChatterFeedElementDto updateFeed(String feedElementId, String text) {
        return ChatterDtoMapper.toFeedElement(ChatterFeedService.updateFeedElement(feedElementId, text));
    }

    @AuraEnabled
    public static void deleteFeedElement(String feedElementId) {
        ChatterFeedService.deleteFeedElement(feedElementId);
    }

    // LIKES
    @AuraEnabled public static String likeFeedElement(String feedElementId) { return ChatterFeedService.likeElement(feedElementId); }
    @AuraEnabled public static void   unlikeFeedElement(String likeId)       { ChatterFeedService.unlikeElement(likeId); }
    @AuraEnabled public static String likeComment(String commentId)          { return ChatterCommentService.likeComment(commentId); }
    @AuraEnabled public static void   unlikeComment(String likeId)           { ChatterCommentService.unlikeComment(likeId); }

    // COMMENTS (not cacheable — comments must reflect fresh state after post/edit)
    @AuraEnabled
    public static ChatterCommentPageDto getComments(String feedElementId, String pageToken, Integer pageSize) {
        return ChatterDtoMapper.toCommentPage(ChatterCommentService.getComments(feedElementId, pageToken, pageSize));
    }

    @AuraEnabled
    public static ChatterCommentDto postComment(String feedElementId, String text) {
        return ChatterDtoMapper.toComment(ChatterCommentService.postComment(feedElementId, text));
    }

    @AuraEnabled
    public static ChatterCommentDto updateComment(String commentId, String text) {
        return ChatterDtoMapper.toComment(ChatterCommentService.updateComment(commentId, text));
    }

    @AuraEnabled
    public static void deleteComment(String commentId) {
        ChatterCommentService.deleteComment(commentId);
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
    public static ChatterPostResultDto postCommentWithFiles(
        String feedElementId,
        String text,
        List<String> contentVersionIds
    ) {
        return ChatterFileService.postCommentWithFiles(feedElementId, text, contentVersionIds);
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
    public static ChatterCommentDto updateCommentWithFiles(
        String commentId,
        String text,
        List<String> newContentVersionIds
    ) {
        return ChatterDtoMapper.toComment(
            ChatterCommentService.updateCommentWithFiles(commentId, text, newContentVersionIds)
        );
    }
    
    @AuraEnabled
    public static String uploadFile(String filename, String base64Data, String mimeType) {
        return ChatterFileService.uploadFile(filename, base64Data, mimeType);
    }

    // MENTIONS
    @AuraEnabled(cacheable=true)
    public static List<ChatterMentionDto> searchMentions(String term, Integer limitSize) {
        return ChatterMentionService.search(term, limitSize);
    }

    // CURRENT USER
    @AuraEnabled(cacheable=true)
    public static User getCurrentUser() {
        return [
            SELECT Id, Name, SmallPhotoUrl, FullPhotoUrl, Title
            FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
        ];
    }

    @AuraEnabled
    public static List<ChatterCommentDto> getCommentEnrichment(List<String> commentIds) {
        if (commentIds == null || commentIds.isEmpty()) {
            return new List<ChatterCommentDto>();
        }
        if (commentIds.size() > 50) {
            List<String> capped = new List<String>();
            for (Integer i = 0; i < 50; i++) capped.add(commentIds[i]);
            commentIds = capped;
        }
        return ChatterDtoMapper.enrichComments(commentIds);
    }

    @AuraEnabled
    public static Map<String, Boolean> getFeedEditPermissions(List<String> feedElementIds) {
        Map<String, Boolean> empty = new Map<String, Boolean>();
        if (feedElementIds == null || feedElementIds.isEmpty()) return empty;
        if (feedElementIds.size() > 50) {
            List<String> capped = new List<String>();
            for (Integer i = 0; i < 50; i++) capped.add(feedElementIds[i]);
            feedElementIds = capped;
        }
        return ChatterDtoMapper.enrichFeedEditPermissions(feedElementIds);
    }

    @AuraEnabled
    public static void deleteAttachment(String contentVersionId) {
        ChatterFileService.deleteAttachment(contentVersionId);
    }
}