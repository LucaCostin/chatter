@isTest
private class ChatterFileServiceTest {

    @isTest
    static void testUploadFile() {
        String base64 = EncodingUtil.base64Encode(Blob.valueOf('Hello, world'));

        Test.startTest();
        String cvId = ChatterFileService.uploadFile('test.txt', base64, 'text/plain');
        Test.stopTest();

        System.assertNotEquals(null, cvId, 'Should return a ContentVersion Id');
        List<ContentVersion> cvs = [SELECT Id, Title FROM ContentVersion WHERE Id = :cvId];
        System.assertEquals(1, cvs.size(), 'ContentVersion should exist');
        System.assertEquals('test', cvs[0].Title, 'Title should have extension stripped');
    }

    @isTest
    static void testUploadFileRejectsBlankFilename() {
        String base64 = EncodingUtil.base64Encode(Blob.valueOf('data'));
        try {
            ChatterFileService.uploadFile('', base64, 'text/plain');
            System.assert(false, 'Should throw');
        } catch (ChatterException e) {
            System.assert(true);
        }
    }

    @isTest
    static void testUploadFileRejectsBlankData() {
        try {
            ChatterFileService.uploadFile('test.txt', '', 'text/plain');
            System.assert(false, 'Should throw');
        } catch (ChatterException e) {
            System.assert(true);
        }
    }

    @isTest
    static void testUploadFileRejectsBlockedMimeType() {
        String base64 = EncodingUtil.base64Encode(Blob.valueOf('<script>alert(1)</script>'));
        try {
            ChatterFileService.uploadFile('malicious.html', base64, 'text/html');
            System.assert(false, 'Should reject text/html');
        } catch (ChatterException e) {
            System.assert(true);
        }
    }

    @isTest
    static void testUploadFileRejectsOversize() {
        // Create a > 5MB payload
        Blob big = Blob.valueOf('x'.repeat(5242881));
        String base64 = EncodingUtil.base64Encode(big);
        try {
            ChatterFileService.uploadFile('big.txt', base64, 'text/plain');
            System.assert(false, 'Should reject >5MB');
        } catch (ChatterException e) {
            System.assert(true);
        }
    }

    @isTest
    static void testDeleteAttachmentNoRows() {
        // Non-existent ContentVersion Id — should not throw
        Test.startTest();
        ChatterFileService.deleteAttachment('068' + '000000000000');
        Test.stopTest();
        System.assert(true, 'No rows to delete should be a no-op');
    }

    @isTest
    static void testDeleteAttachmentBlankId() {
        try {
            ChatterFileService.deleteAttachment('');
            System.assert(false, 'Should throw');
        } catch (ChatterException e) {
            System.assert(true);
        }
    }
}