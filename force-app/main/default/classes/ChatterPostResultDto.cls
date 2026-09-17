/**
 * Wrapper returned by postFeedWithFile and postCommentWithFile.
 * Always contains the created post (if posting succeeded).
 * attachmentError is populated when the file could not be linked —
 * the post is still valid, the file just didn't make it.
 */
public with sharing class ChatterPostResultDto {
    @AuraEnabled public ChatterFeedElementDto element;
    @AuraEnabled public ChatterCommentDto     comment;
    @AuraEnabled public String                attachmentError;
}