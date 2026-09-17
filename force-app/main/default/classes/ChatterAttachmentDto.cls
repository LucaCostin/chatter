public with sharing class ChatterAttachmentDto {
    @AuraEnabled public String  id;                 // ContentDocumentId (069...)
    @AuraEnabled public String  contentVersionId;   // ContentVersionId (068...) — NEW
    @AuraEnabled public String  title;
    @AuraEnabled public String  url;
    @AuraEnabled public String  mimeType;
    @AuraEnabled public Integer fileSize;
    @AuraEnabled public String  fileExtension;
    @AuraEnabled public Boolean canDelete;          // NEW
}