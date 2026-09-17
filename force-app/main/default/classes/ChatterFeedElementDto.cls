public with sharing class ChatterFeedElementDto {
    @AuraEnabled public String  id;
    @AuraEnabled public String  feedElementType;
    @AuraEnabled public String  createdDate;
    @AuraEnabled public String  url;
    @AuraEnabled public String  actorId;
    @AuraEnabled public String  actorName;
    @AuraEnabled public String  actorPhoto;
    @AuraEnabled public String  text;
    @AuraEnabled public Integer likeCount;
    @AuraEnabled public Boolean currentUserLike;
    @AuraEnabled public String  myLikeId;
    @AuraEnabled public Integer commentCount;
    @AuraEnabled public Boolean isBookmarked;
    @AuraEnabled public Boolean canEdit;
    @AuraEnabled public Boolean canDelete;
    @AuraEnabled public List<ChatterAttachmentDto> attachments;
    @AuraEnabled public List<ChatterInlineImageDto> inlineImages;   // ← NEW

    public ChatterFeedElementDto() {
        this.likeCount       = 0;
        this.commentCount    = 0;
        this.currentUserLike = false;
        this.isBookmarked    = false;
        this.canEdit         = false;
        this.canDelete       = true;
        this.attachments     = new List<ChatterAttachmentDto>();
        this.inlineImages    = new List<ChatterInlineImageDto>();     // ← NEW
    }
}