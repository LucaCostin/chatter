public with sharing class ChatterCommentDto {
    @AuraEnabled public String  id;
    @AuraEnabled public String  createdDate;
    @AuraEnabled public String  url;
    @AuraEnabled public String  authorId;
    @AuraEnabled public String  authorName;
    @AuraEnabled public String  authorPhoto;
    @AuraEnabled public String  text;
    @AuraEnabled public Integer likeCount;
    @AuraEnabled public Boolean currentUserLike;
    @AuraEnabled public String  myLikeId;
    @AuraEnabled public String  parentId;
    @AuraEnabled public Boolean canEdit;
    @AuraEnabled public List<ChatterInlineImageDto> inlineImages;

    public ChatterCommentDto() {
        this.likeCount       = 0;
        this.currentUserLike = false;
        this.canEdit         = false;
        this.inlineImages    = new List<ChatterInlineImageDto>();
    }
}