@isTest
private class ChatterSoqlSanitizerTest {

    // ============================================================
    //  IDENTIFIER
    // ============================================================

    @isTest
    static void testIdentifierValid() {
        System.assertEquals('Name', ChatterSoqlSanitizer.identifier('Name'));
        System.assertEquals('CaseNumber', ChatterSoqlSanitizer.identifier('CaseNumber'));
        System.assertEquals('Custom_Field__c', ChatterSoqlSanitizer.identifier('Custom_Field__c'));
    }

    @isTest
    static void testIdentifierTrimmed() {
        System.assertEquals('Name', ChatterSoqlSanitizer.identifier('  Name  '));
    }

    @isTest
    static void testIdentifierBlank() {
        System.assertEquals(null, ChatterSoqlSanitizer.identifier(null));
        System.assertEquals(null, ChatterSoqlSanitizer.identifier(''));
        System.assertEquals(null, ChatterSoqlSanitizer.identifier('   '));
    }

    @isTest
    static void testIdentifierRejectsInjection() {
        try {
            ChatterSoqlSanitizer.identifier('Name; DELETE FROM Account');
            System.assert(false, 'Should have thrown');
        } catch (ChatterException e) {
            System.assert(true);
        }
    }

    @isTest
    static void testIdentifierRejectsStartingWithDigit() {
        try {
            ChatterSoqlSanitizer.identifier('1Name');
            System.assert(false, 'Should have thrown');
        } catch (ChatterException e) {
            System.assert(true);
        }
    }

    // ============================================================
    //  FILTER
    // ============================================================

    @isTest
    static void testFilterValid() {
        System.assertEquals('\'Open\'', ChatterSoqlSanitizer.filter('\'Open\''));
        System.assertEquals('IsClosed = false', ChatterSoqlSanitizer.filter('IsClosed = false'));
    }

    @isTest
    static void testFilterBlank() {
        System.assertEquals(null, ChatterSoqlSanitizer.filter(null));
        System.assertEquals(null, ChatterSoqlSanitizer.filter(''));
    }

    @isTest
    static void testFilterRejectsSemicolon() {
        assertFilterRejected('Status = \'Open\'; DROP');
    }

    @isTest
    static void testFilterRejectsComment() {
        assertFilterRejected('Status = \'Open\' --');
        assertFilterRejected('Status = \'Open\' /* x */');
    }

    @isTest
    static void testFilterRejectsKeywords() {
        assertFilterRejected('LIMIT 1');
        assertFilterRejected('SELECT Id FROM Account');
        assertFilterRejected('DELETE FROM Account');
        assertFilterRejected('UNION SELECT');
    }

    @isTest
    static void testFilterRejectsInvalidChars() {
        // Double-quote is not in the allowed character class
        assertFilterRejected('Status = "Open"');
    }

    private static void assertFilterRejected(String input) {
        try {
            ChatterSoqlSanitizer.filter(input);
            System.assert(false, 'Should have rejected: ' + input);
        } catch (ChatterException e) {
            System.assert(true);
        }
    }

    // ============================================================
    //  ORDER BY
    // ============================================================

    @isTest
    static void testOrderByValid() {
        System.assertEquals('Name ASC', ChatterSoqlSanitizer.orderBy('Name ASC'));
        System.assertEquals('LastModifiedDate DESC', ChatterSoqlSanitizer.orderBy('LastModifiedDate DESC'));
        System.assertEquals('Name, CreatedDate DESC', ChatterSoqlSanitizer.orderBy('Name, CreatedDate DESC'));
    }

    @isTest
    static void testOrderByBlank() {
        System.assertEquals(null, ChatterSoqlSanitizer.orderBy(null));
        System.assertEquals(null, ChatterSoqlSanitizer.orderBy(''));
    }

    @isTest
    static void testOrderByRejectsInjection() {
        try {
            ChatterSoqlSanitizer.orderBy('Name; DROP');
            System.assert(false, 'Should have thrown');
        } catch (ChatterException e) {
            System.assert(true);
        }
    }

    // ============================================================
    //  LIMIT CLAMP
    // ============================================================

    @isTest
    static void testLimitClampDefaults() {
        System.assertEquals(25, ChatterSoqlSanitizer.limitClamp(null, 25, 1, 200));
    }

    @isTest
    static void testLimitClampUnderMin() {
        System.assertEquals(1, ChatterSoqlSanitizer.limitClamp(-5, 25, 1, 200));
        System.assertEquals(1, ChatterSoqlSanitizer.limitClamp(0, 25, 1, 200));
    }

    @isTest
    static void testLimitClampOverMax() {
        System.assertEquals(200, ChatterSoqlSanitizer.limitClamp(9999, 25, 1, 200));
    }

    @isTest
    static void testLimitClampInRange() {
        System.assertEquals(50, ChatterSoqlSanitizer.limitClamp(50, 25, 1, 200));
    }
}