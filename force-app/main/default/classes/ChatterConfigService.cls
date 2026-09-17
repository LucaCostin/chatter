public with sharing class ChatterConfigService {

    private static final Integer DEFAULT_LIMIT = 25;
    private static final Integer MAX_LIMIT     = 200;

    public static List<ChatterConfigDto> getConfigs() {
        List<Emerald_Chatter_Config__mdt> rows = [
            SELECT Id, MasterLabel, DeveloperName,
                   Object_API_Name__c, Record_Filter__c, Order_By__c, Limit__c,
                   Label_Field__c, Subtitle_Field__c, Icon__c, Sort_Order__c
            FROM Emerald_Chatter_Config__mdt
            WHERE Active__c = true
            ORDER BY Sort_Order__c ASC, MasterLabel ASC
        ];
        List<ChatterConfigDto> out = new List<ChatterConfigDto>();
        for (Emerald_Chatter_Config__mdt r : rows) out.add(toDto(r));
        return out;
    }

    public static List<ChatterRecordDto> getRecordsForConfig(String configDeveloperName) {
        if (String.isBlank(configDeveloperName)) {
            throw ChatterException.validation('configDeveloperName is required');
        }
        List<Emerald_Chatter_Config__mdt> found = [
            SELECT Object_API_Name__c, Record_Filter__c, Order_By__c, Limit__c,
                   Label_Field__c, Subtitle_Field__c
            FROM Emerald_Chatter_Config__mdt
            WHERE DeveloperName = :configDeveloperName AND Active__c = true
            LIMIT 1
        ];
        if (found.isEmpty()) throw ChatterException.notFound('Config not found: ' + configDeveloperName);
        Emerald_Chatter_Config__mdt cfg = found[0];

        String objName = cfg.Object_API_Name__c;
        if (String.isBlank(objName)) throw ChatterException.validation('Config has no Object_API_Name__c');

        Schema.SObjectType sot = Schema.getGlobalDescribe().get(objName);
        if (sot == null || !sot.getDescribe().isAccessible()) {
            throw ChatterException.security('No access to object: ' + objName);
        }

        String labelField    = ChatterSoqlSanitizer.identifier(cfg.Label_Field__c);
        String subtitleField = ChatterSoqlSanitizer.identifier(cfg.Subtitle_Field__c);
        if (String.isBlank(labelField)) labelField = 'Name';

        Set<String> selectFields = new Set<String>{ 'Id', labelField };
        if (String.isNotBlank(subtitleField)) selectFields.add(subtitleField);

        String soql = 'SELECT ' + String.join(new List<String>(selectFields), ', ')
                    + ' FROM ' + objName;

        String whereClause = ChatterSoqlSanitizer.filter(cfg.Record_Filter__c);
        if (String.isNotBlank(whereClause)) soql += ' WHERE ' + whereClause;

        String orderBy = ChatterSoqlSanitizer.orderBy(cfg.Order_By__c);
        soql += ' ORDER BY ' + (String.isNotBlank(orderBy) ? orderBy : 'LastModifiedDate DESC');

        Integer lim = ChatterSoqlSanitizer.limitClamp(cfg.Limit__c, DEFAULT_LIMIT, 1, MAX_LIMIT);
        soql += ' LIMIT ' + lim;

        List<SObject> raw;
        try { raw = Database.query(soql); }
        catch (QueryException qe) {
            throw ChatterException.validation('Query failed for ' + objName + ': ' + qe.getMessage());
        }

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, raw);
        List<SObject> safe = decision.getRecords();

        List<ChatterRecordDto> out = new List<ChatterRecordDto>();
        for (SObject s : safe) {
            ChatterRecordDto d = new ChatterRecordDto();
            d.id            = (String) s.get('Id');
            d.objectApiName = objName;
            d.label         = String.valueOf(s.get(labelField));
            if (String.isNotBlank(subtitleField)) {
                Object sub = s.get(subtitleField);
                d.subtitle = sub == null ? null : String.valueOf(sub);
            }
            out.add(d);
        }
        return out;
    }

    private static ChatterConfigDto toDto(Emerald_Chatter_Config__mdt r) {
        ChatterConfigDto d = new ChatterConfigDto();
        d.id            = r.Id;
        d.developerName = r.DeveloperName;
        d.label         = r.MasterLabel;
        d.objectApiName = r.Object_API_Name__c;
        d.recordFilter  = r.Record_Filter__c;
        d.orderBy       = r.Order_By__c;
        d.limitSize     = r.Limit__c == null ? DEFAULT_LIMIT : Integer.valueOf(r.Limit__c);
        d.labelField    = r.Label_Field__c;
        d.subtitleField = r.Subtitle_Field__c;
        d.icon          = String.isBlank(r.Icon__c) ? 'standard:record' : r.Icon__c;
        d.sortOrder     = r.Sort_Order__c == null ? 999 : Integer.valueOf(r.Sort_Order__c);
        return d;
    }
}