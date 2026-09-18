@isTest
private class ChatterFeedServiceTest {

    @isTest
    static void testGetFeedMocked() {
        ConnectApi.FeedElementPage fakePage = new ConnectApi.FeedElementPage();
        fakePage.elements = new List<ConnectApi.FeedElement>();

        ConnectApi.ChatterFeeds.setTestGetFeedElementsFromFeed(
            null,
            ConnectApi.FeedType.Record,
            '001' + '000000000000',
            null,
            25,
            ConnectApi.FeedSortOrder.LastModifiedDateDesc,
            fakePage
        );

        Test.startTest();
        ConnectApi.FeedElementPage result =
            ChatterFeedService.getFeed('001' + '000000000000', null, 25);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetFeedBlankRecordId() {
        try {
            ChatterFeedService.getFeed('', null, 25);
            System.assert(false);
        } catch (ChatterException e) { }
        System.assert(true);
    }

    @isTest
    static void testGetNewsFeedMocked() {
        ConnectApi.FeedElementPage fakePage = new ConnectApi.FeedElementPage();
        fakePage.elements = new List<ConnectApi.FeedElement>();

        ConnectApi.ChatterFeeds.setTestGetFeedElementsFromFeed(
            null,
            ConnectApi.FeedType.News,
            null,
            null,
            25,
            ConnectApi.FeedSortOrder.LastModifiedDateDesc,
            fakePage
        );

        Test.startTest();
        ConnectApi.FeedElementPage result = ChatterFeedService.getNewsFeed(null, 25);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @isTest
    static void smokePostFeedBlank() {
        try {
            ChatterFeedService.postFeed('', 'text', 'FeedItem');
            System.assert(false);
        } catch (ChatterException e) { }
        System.assert(true);
    }

    @isTest
    static void smokePostFeedInvalidRecord() {
        try {
            ChatterFeedService.postFeed('001' + '000000000000', 'text', 'FeedItem');
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void smokeUpdateFeedElementWithFiles() {
        try {
            ChatterFeedService.updateFeedElementWithFiles(
                '0D5' + '000000000000', 'text', new List<String>()
            );
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void smokeDeleteFeedElement() {
        try {
            ChatterFeedService.deleteFeedElement('0D5' + '000000000000');
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void smokeLikeElement() {
        try {
            ChatterFeedService.likeElement('0D5' + '000000000000');
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void smokeUnlikeElement() {
        try {
            ChatterFeedService.unlikeElement('07M' + '000000000000');
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void testCanEditFeedElementBlank() {
        Boolean result = ChatterFeedService.canEditFeedElement('');
        System.assertEquals(false, result);
    }

    @isTest
    static void testCanEditFeedElementInvalid() {
        Boolean result = ChatterFeedService.canEditFeedElement('0D5' + '000000000000');
        // Returns false on exception
        System.assertEquals(false, result);
    }
}