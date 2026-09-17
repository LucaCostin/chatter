public with sharing class ChatterFeedPageDto {
    @AuraEnabled public List<ChatterFeedElementDto> elements;
    @AuraEnabled public String nextPageToken;

    public ChatterFeedPageDto() {
        this.elements = new List<ChatterFeedElementDto>();
    }
}