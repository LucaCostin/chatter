@isTest
private class ChatterMentionServiceTest {

    @TestSetup
    static void setup() {
        // Create test users with unique names
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        List<User> usersToCreate = new List<User>();
        for (Integer i = 0; i < 3; i++) {
            usersToCreate.add(new User(
                FirstName = 'Test',
                LastName  = 'Mention' + i,
                Alias     = 'tmn' + i,
                Email     = 'mention' + i + '@example.com',
                Username  = 'mention' + i + i + '@example.com.test' + i,
                ProfileId = p.Id,
                TimeZoneSidKey    = 'America/Los_Angeles',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            ));
        }
        insert usersToCreate;
    }

    @isTest
    static void testSearchEmptyTerm() {
        List<ChatterMentionDto> results = ChatterMentionService.search('', 8);
        System.assertEquals(0, results.size(), 'Empty term should return nothing');
    }

    @isTest
    static void testSearchNullTerm() {
        List<ChatterMentionDto> results = ChatterMentionService.search(null, 8);
        System.assertEquals(0, results.size(), 'Null term should return nothing');
    }

    @isTest
    static void testSearchByFirstName() {
        List<ChatterMentionDto> results = ChatterMentionService.search('Test', 8);
        System.assertNotEquals(0, results.size(), 'Should match Test users');

        Boolean foundUser = false;
        for (ChatterMentionDto d : results) {
            if (d.type == 'User' && d.name != null && d.name.contains('Test')) {
                foundUser = true;
                break;
            }
        }
        System.assert(foundUser, 'Should find at least one Test user');
    }

    @isTest
    static void testSearchRespectsLimit() {
        List<ChatterMentionDto> results = ChatterMentionService.search('Test', 2);
        System.assert(results.size() <= 2, 'Should not exceed requested limit');
    }

    @isTest
    static void testSearchClampsMinimumLimit() {
        List<ChatterMentionDto> results = ChatterMentionService.search('Test', 0);
        System.assert(results.size() <= 1, 'Should clamp to 1');
    }

    @isTest
    static void testSearchClampsMaximumLimit() {
        List<ChatterMentionDto> results = ChatterMentionService.search('Test', 9999);
        System.assert(results.size() <= 25, 'Should clamp to 25 max');
    }
}