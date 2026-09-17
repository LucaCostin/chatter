public with sharing class ChatterConfigDto {
    @AuraEnabled public String  id;
    @AuraEnabled public String  developerName;
    @AuraEnabled public String  label;
    @AuraEnabled public String  objectApiName;
    @AuraEnabled public String  recordFilter;
    @AuraEnabled public String  orderBy;
    @AuraEnabled public Integer limitSize;
    @AuraEnabled public String  labelField;
    @AuraEnabled public String  subtitleField;
    @AuraEnabled public String  icon;
    @AuraEnabled public Integer sortOrder;
}