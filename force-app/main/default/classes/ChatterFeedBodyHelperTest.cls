@isTest
private class ChatterFeedBodyHelperTest {

    @isTest
    static void testBuildRichBodyWithHtml() {
        ConnectApi.MessageBodyInput body = ChatterFeedBodyHelper.buildRichBody('<p>Hello</p>');
        System.assertNotEquals(null, body, 'Body should not be null');
        System.assertNotEquals(null, body.messageSegments, 'Should have segments');
        System.assertEquals(3, body.messageSegments.size(),
            'Should parse <p>Hello</p> into 3 segments (open, text, close)');
    }

    @isTest
    static void testBuildRichBodyWithBlank() {
        ConnectApi.MessageBodyInput body = ChatterFeedBodyHelper.buildRichBody('');
        System.assertNotEquals(null, body);
        System.assertEquals(1, body.messageSegments.size(), 'Blank should produce empty text segment');
    }

    @isTest
    static void testBuildRichBodyWithNull() {
        ConnectApi.MessageBodyInput body = ChatterFeedBodyHelper.buildRichBody(null);
        System.assertNotEquals(null, body);
        System.assertEquals(1, body.messageSegments.size());
    }

    @isTest
    static void testBuildRichBodyWithMention() {
        // Helper should parse {005...} into a mention segment
        String fakeId = '005' + '000000000000'; // 15 char
        ConnectApi.MessageBodyInput body = ChatterFeedBodyHelper.buildRichBody('Hi {' + fakeId + '}!');
        System.assertNotEquals(null, body);
        System.assertNotEquals(null, body.messageSegments);
    }

    // ============================================================
    //  CAP LIST
    // ============================================================

    @isTest
    static void testCapListUnderMax() {
        List<String> source = new List<String>{ 'a', 'b', 'c' };
        List<String> result = ChatterFeedBodyHelper.capList(source, 10);
        System.assertEquals(3, result.size());
    }

    @isTest
    static void testCapListOverMax() {
        List<String> source = new List<String>{ 'a', 'b', 'c', 'd', 'e' };
        List<String> result = ChatterFeedBodyHelper.capList(source, 3);
        System.assertEquals(3, result.size());
        System.assertEquals('a', result[0]);
        System.assertEquals('c', result[2]);
    }

    @isTest
    static void testCapListExactMatch() {
        List<String> source = new List<String>{ 'a', 'b', 'c' };
        List<String> result = ChatterFeedBodyHelper.capList(source, 3);
        System.assertEquals(3, result.size());
    }

    @isTest
    static void testCapListNull() {
        List<String> result = ChatterFeedBodyHelper.capList(null, 10);
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testCapListEmpty() {
        List<String> result = ChatterFeedBodyHelper.capList(new List<String>(), 10);
        System.assertEquals(0, result.size());
    }

    // ============================================================
    //  TRY LINK FILE (negative case — content version doesn't exist)
    // ============================================================

    @isTest
    static void testTryLinkFileInvalidIds() {
        // Use a valid-looking but non-existent FeedEntity and ContentVersion
        String result = ChatterFeedBodyHelper.tryLinkFile(
            '0D5' + '000000000000',
            '068' + '000000000000'
        );
        System.assertNotEquals(null, result, 'Should return error for non-existent records');
    }
}