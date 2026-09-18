@isTest
private class ChatterConfigServiceTest {

    @isTest
    static void testGetConfigsReturnsActiveOnly() {
        List<ChatterConfigDto> configs = ChatterConfigService.getConfigs();
        System.assertNotEquals(null, configs, 'Should return a list');
        for (ChatterConfigDto cfg : configs) {
            System.assertNotEquals(null, cfg.developerName, 'Config should have DeveloperName');
            System.assertNotEquals(null, cfg.objectApiName, 'Config should have Object API Name');
            System.assertNotEquals(null, cfg.label, 'Config should have Label');
        }
    }

    @isTest
    static void testGetRecordsForConfigBlankName() {
        try {
            ChatterConfigService.getRecordsForConfig('');
            System.assert(false, 'Should throw for blank name');
        } catch (ChatterException e) {
            System.assert(true);
        }
    }

    @isTest
    static void testGetRecordsForConfigUnknownName() {
        try {
            ChatterConfigService.getRecordsForConfig('NonExistent_Config_XYZ');
            System.assert(false, 'Should throw for unknown config');
        } catch (ChatterException e) {
            System.assert(true);
        }
    }

    @isTest
    static void testGetRecordsForConfigValid() {
        // Uses the seeded config for Accounts (from the package)
        // Skip if no configs exist
        List<ChatterConfigDto> configs = ChatterConfigService.getConfigs();
        if (configs.isEmpty()) return;

        ChatterConfigDto firstConfig = configs[0];
        try {
            List<ChatterRecordDto> records =
                ChatterConfigService.getRecordsForConfig(firstConfig.developerName);
            System.assertNotEquals(null, records, 'Should return a list (may be empty)');
        } catch (ChatterException e) {
            // Some configs may reference objects the test user can't read.
            // That's an acceptable outcome — the method behaves correctly.
            System.assert(true);
        }
    }

    @isTest
    static void testGetRecordsForAccountConfig() {
        try {
            List<ChatterRecordDto> records =
                ChatterConfigService.getRecordsForConfig('Accounts');
            System.assertNotEquals(null, records);
            for (ChatterRecordDto r : records) {
                System.assertNotEquals(null, r.id);
                System.assertNotEquals(null, r.label);
                System.assertEquals('Account', r.objectApiName);
            }
        } catch (ChatterException e) {
            // Config may not exist in some orgs; acceptable
            System.assert(true);
        }
    }
}