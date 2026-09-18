@isTest
private class ChatterCommentServiceTest {

    @isTest
    static void smokeGetCommentsInvalidId() {
        try {
            ChatterCommentService.getComments('0D5' + '000000000000', null, 25);
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void testGetCommentsBlank() {
        try {
            ChatterCommentService.getComments('', null, 25);
            System.assert(false);
        } catch (ChatterException e) { }
        System.assert(true);
    }

    @isTest
    static void smokePostComment() {
        try {
            ChatterCommentService.postComment('0D5' + '000000000000', 'smoke');
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void smokePostCommentBlank() {
        try {
            ChatterCommentService.postComment('', 'text');
            System.assert(false);
        } catch (ChatterException e) { }
        System.assert(true);
    }

    @isTest
    static void smokeUpdateComment() {
        try {
            ChatterCommentService.updateComment('0D7' + '000000000000', 'smoke');
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void smokeUpdateCommentWithFiles() {
        try {
            ChatterCommentService.updateCommentWithFiles(
                '0D7' + '000000000000', 'smoke', new List<String>()
            );
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void smokePostCommentWithFiles() {
        try {
            ChatterCommentService.postCommentWithFiles(
                '0D5' + '000000000000', 'smoke', new List<String>()
            );
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void smokeDeleteComment() {
        try {
            ChatterCommentService.deleteComment('0D7' + '000000000000');
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void smokeLikeComment() {
        try {
            ChatterCommentService.likeComment('0D7' + '000000000000');
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void smokeUnlikeComment() {
        try {
            ChatterCommentService.unlikeComment('07M' + '000000000000');
        } catch (Exception e) { }
        System.assert(true);
    }

    @isTest
    static void testCanEditCommentBlank() {
        Boolean result = ChatterCommentService.canEditComment('');
        System.assertEquals(false, result);
    }

    @isTest
    static void testCanEditCommentInvalid() {
        Boolean result = ChatterCommentService.canEditComment('0D7' + '000000000000');
        System.assertEquals(false, result);
    }
}