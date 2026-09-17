public with sharing class ChatterInlineImageDto {
    @AuraEnabled public String  url;
    @AuraEnabled public String  thumbnailUrl;
    @AuraEnabled public String  altText;
    @AuraEnabled public String  contentDocumentId;
    @AuraEnabled public String  contentVersionId;
    @AuraEnabled public Integer position;
}