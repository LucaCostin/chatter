public with sharing class ChatterCommentPageDto {
    @AuraEnabled public List<ChatterCommentDto> comments;
    @AuraEnabled public String  nextPageToken;
    @AuraEnabled public Integer total;

    public ChatterCommentPageDto() {
        this.comments = new List<ChatterCommentDto>();
        this.total    = 0;
    }
}