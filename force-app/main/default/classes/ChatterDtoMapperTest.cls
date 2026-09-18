/**
 * Real unit tests for ChatterDtoMapper.
 *
 * Uses the Connect API test pattern from:
 *   https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_connectapi_testing.htm
 *
 * Every Connect API output class is a non-abstract, no-arg-constructible class.
 * We build fake elements in memory, pass them to the mapper, and assert on the
 * resulting DTOs. No mocks, no SeeAllData, no network calls.
 *
 * Some output classes (ActorWithId, Reference.name) have visibility constraints
 * that prevent test construction — tests for those paths are omitted. Coverage
 * for those specific branches is not achievable via the Apex test framework.
 */
@isTest
private class ChatterDtoMapperTest {

    // ============================================================
    //  NULL INPUTS
    // ============================================================

    @isTest
    static void testToFeedPageWithNull() {
        ChatterFeedPageDto dto = ChatterDtoMapper.toFeedPage(null);
        System.assertNotEquals(null, dto);
        System.assertEquals(0, dto.elements.size());
    }

    @isTest
    static void testToFeedElementWithNull() {
        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement(null);
        System.assertNotEquals(null, dto);
        System.assertEquals(null, dto.id);
        System.assertEquals(0, dto.likeCount);
        System.assertEquals(false, dto.currentUserLike);
    }

    @isTest
    static void testToCommentPageWithNull() {
        ChatterCommentPageDto dto = ChatterDtoMapper.toCommentPage(null);
        System.assertNotEquals(null, dto);
        System.assertEquals(0, dto.comments.size());
    }

    @isTest
    static void testToCommentWithNull() {
        ChatterCommentDto dto = ChatterDtoMapper.toComment(null);
        System.assertNotEquals(null, dto);
    }

    // ============================================================
    //  FEED ITEM — PLAIN TEXT
    // ============================================================

    @isTest
    static void testFeedItemPlainText() {
        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000001');
        item.body = buildBody(new List<ConnectApi.MessageSegment>{
            buildTextSegment('Hello world')
        });

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assertEquals('0D5' + '0000000000001', dto.id);
        System.assertEquals('Hello world', dto.text);
    }

    // ============================================================
    //  FEED ITEM — LINK
    // ============================================================

    @isTest
    static void testFeedItemWithLink() {
        ConnectApi.LinkSegment link = new ConnectApi.LinkSegment();
        link.url = 'https://example.com';

        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000003');
        item.body = buildBody(new List<ConnectApi.MessageSegment>{ link });

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assert(dto.text.contains('https://example.com'),
            'Should include URL. Got: ' + dto.text);
    }

    // ============================================================
    //  FEED ITEM — HASHTAG
    // ============================================================

    @isTest
    static void testFeedItemWithHashtag() {
        ConnectApi.HashtagSegment tag = new ConnectApi.HashtagSegment();
        tag.tag = 'yolo';

        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000004');
        item.body = buildBody(new List<ConnectApi.MessageSegment>{ tag });

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assert(dto.text.contains('#yolo'), 'Should include hashtag. Got: ' + dto.text);
    }

    // ============================================================
    //  FEED ITEM — MARKUP (BOLD)
    // ============================================================

    @isTest
    static void testFeedItemWithBoldMarkup() {
        ConnectApi.MarkupBeginSegment beginSeg = new ConnectApi.MarkupBeginSegment();
        beginSeg.markupType = ConnectApi.MarkupType.Bold;

        ConnectApi.MarkupEndSegment endSeg = new ConnectApi.MarkupEndSegment();
        endSeg.markupType = ConnectApi.MarkupType.Bold;

        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000005');
        item.body = buildBody(new List<ConnectApi.MessageSegment>{
            beginSeg,
            buildTextSegment('bold'),
            endSeg
        });

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assert(dto.text.contains('<b>'), 'Missing <b>. Got: ' + dto.text);
        System.assert(dto.text.contains('</b>'), 'Missing </b>. Got: ' + dto.text);
        System.assert(dto.text.contains('bold'), 'Missing content. Got: ' + dto.text);
    }

    @isTest
    static void testFeedItemWithItalicMarkup() {
        ConnectApi.MarkupBeginSegment beginSeg = new ConnectApi.MarkupBeginSegment();
        beginSeg.markupType = ConnectApi.MarkupType.Italic;

        ConnectApi.MarkupEndSegment endSeg = new ConnectApi.MarkupEndSegment();
        endSeg.markupType = ConnectApi.MarkupType.Italic;

        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000006');
        item.body = buildBody(new List<ConnectApi.MessageSegment>{
            beginSeg, buildTextSegment('x'), endSeg
        });

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assert(dto.text.contains('<i>'), 'Missing <i>. Got: ' + dto.text);
        System.assert(dto.text.contains('</i>'), 'Missing </i>. Got: ' + dto.text);
    }

    @isTest
    static void testFeedItemWithUnderlineMarkup() {
        ConnectApi.MarkupBeginSegment beginSeg = new ConnectApi.MarkupBeginSegment();
        beginSeg.markupType = ConnectApi.MarkupType.Underline;

        ConnectApi.MarkupEndSegment endSeg = new ConnectApi.MarkupEndSegment();
        endSeg.markupType = ConnectApi.MarkupType.Underline;

        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000007');
        item.body = buildBody(new List<ConnectApi.MessageSegment>{
            beginSeg, buildTextSegment('x'), endSeg
        });

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assert(dto.text.contains('<u>'), 'Missing <u>. Got: ' + dto.text);
        System.assert(dto.text.contains('</u>'), 'Missing </u>. Got: ' + dto.text);
    }

    @isTest
    static void testFeedItemWithParagraphMarkup() {
        ConnectApi.MarkupBeginSegment beginSeg = new ConnectApi.MarkupBeginSegment();
        beginSeg.markupType = ConnectApi.MarkupType.Paragraph;

        ConnectApi.MarkupEndSegment endSeg = new ConnectApi.MarkupEndSegment();
        endSeg.markupType = ConnectApi.MarkupType.Paragraph;

        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000008');
        item.body = buildBody(new List<ConnectApi.MessageSegment>{
            beginSeg, buildTextSegment('x'), endSeg
        });

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assert(dto.text.contains('<p>'), 'Missing <p>. Got: ' + dto.text);
        System.assert(dto.text.contains('</p>'), 'Missing </p>. Got: ' + dto.text);
    }

    @isTest
    static void testFeedItemWithStrikethroughMarkup() {
        ConnectApi.MarkupBeginSegment beginSeg = new ConnectApi.MarkupBeginSegment();
        beginSeg.markupType = ConnectApi.MarkupType.Strikethrough;

        ConnectApi.MarkupEndSegment endSeg = new ConnectApi.MarkupEndSegment();
        endSeg.markupType = ConnectApi.MarkupType.Strikethrough;

        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000009');
        item.body = buildBody(new List<ConnectApi.MessageSegment>{
            beginSeg, buildTextSegment('x'), endSeg
        });

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assert(dto.text.contains('<s>'), 'Missing <s>. Got: ' + dto.text);
        System.assert(dto.text.contains('</s>'), 'Missing </s>. Got: ' + dto.text);
    }

    @isTest
    static void testFeedItemWithCodeMarkup() {
        ConnectApi.MarkupBeginSegment beginSeg = new ConnectApi.MarkupBeginSegment();
        beginSeg.markupType = ConnectApi.MarkupType.Code;

        ConnectApi.MarkupEndSegment endSeg = new ConnectApi.MarkupEndSegment();
        endSeg.markupType = ConnectApi.MarkupType.Code;

        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000010');
        item.body = buildBody(new List<ConnectApi.MessageSegment>{
            beginSeg, buildTextSegment('code'), endSeg
        });

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assert(dto.text.contains('<code>'), 'Missing <code>. Got: ' + dto.text);
        System.assert(dto.text.contains('</code>'), 'Missing </code>. Got: ' + dto.text);
    }

    // ============================================================
    //  FEED ITEM — INLINE IMAGE
    // ============================================================

    @isTest
    static void testFeedItemWithInlineImage() {
        ConnectApi.InlineImageSegment img = new ConnectApi.InlineImageSegment();
        img.altText = 'A photo';

        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000011');
        item.body = buildBody(new List<ConnectApi.MessageSegment>{ img });

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assertEquals(1, dto.inlineImages.size(), 'Should produce one inline image DTO');
        System.assertEquals('A photo', dto.inlineImages[0].altText);
        System.assert(dto.text.contains('[[IMG:0]]'), 'Should emit token. Got: ' + dto.text);
    }

    // ============================================================
    //  FEED ITEM — LIKES CAPABILITY
    // ============================================================

    @isTest
    static void testFeedItemWithLikesCapability() {
        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000012');

        ConnectApi.FeedElementCapabilities caps = new ConnectApi.FeedElementCapabilities();

        ConnectApi.ChatterLikesCapability likes = new ConnectApi.ChatterLikesCapability();
        likes.isLikedByCurrentUser = true;

        ConnectApi.ChatterLikePage likePage = new ConnectApi.ChatterLikePage();
        likePage.total = 5;
        likes.page = likePage;

        caps.chatterLikes = likes;
        item.capabilities = caps;

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assertEquals(5, dto.likeCount, 'Should read like count from page.total');
        System.assertEquals(true, dto.currentUserLike);
    }

    // ============================================================
    //  FEED ITEM — COMMENTS CAPABILITY
    // ============================================================

    @isTest
    static void testFeedItemWithCommentsCapability() {
        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000013');

        ConnectApi.FeedElementCapabilities caps = new ConnectApi.FeedElementCapabilities();

        ConnectApi.CommentsCapability comments = new ConnectApi.CommentsCapability();
        ConnectApi.CommentPage cpage = new ConnectApi.CommentPage();
        cpage.total = 3;
        comments.page = cpage;

        caps.comments = comments;
        item.capabilities = caps;

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assertEquals(3, dto.commentCount);
    }

    // ============================================================
    //  FEED ITEM — BOOKMARKS CAPABILITY
    // ============================================================

    @isTest
    static void testFeedItemWithBookmarksCapability() {
        ConnectApi.FeedItem item = buildFeedItem('0D5' + '0000000000014');

        ConnectApi.FeedElementCapabilities caps = new ConnectApi.FeedElementCapabilities();
        ConnectApi.BookmarksCapability bookmarks = new ConnectApi.BookmarksCapability();
        bookmarks.isBookmarkedByCurrentUser = true;
        caps.bookmarks = bookmarks;
        item.capabilities = caps;

        ChatterFeedElementDto dto = ChatterDtoMapper.toFeedElement((ConnectApi.FeedElement) item);

        System.assertEquals(true, dto.isBookmarked);
    }

    // ============================================================
    //  FEED PAGE
    // ============================================================

    @isTest
    static void testToFeedPageWithElements() {
        ConnectApi.FeedElementPage page = new ConnectApi.FeedElementPage();
        page.elements = new List<ConnectApi.FeedElement>();

        ConnectApi.FeedItem item1 = buildFeedItem('0D5' + '0000000000015');
        item1.body = buildBody(new List<ConnectApi.MessageSegment>{
            buildTextSegment('Hello')
        });
        page.elements.add((ConnectApi.FeedElement) item1);

        ConnectApi.FeedItem item2 = buildFeedItem('0D5' + '0000000000016');
        item2.body = buildBody(new List<ConnectApi.MessageSegment>{
            buildTextSegment('World')
        });
        page.elements.add((ConnectApi.FeedElement) item2);

        page.nextPageToken = 'token123';

        ChatterFeedPageDto dto = ChatterDtoMapper.toFeedPage(page);

        System.assertEquals(2, dto.elements.size());
        System.assertEquals('0D5' + '0000000000015', dto.elements[0].id);
        System.assertEquals('Hello', dto.elements[0].text);
        System.assertEquals('World', dto.elements[1].text);
        System.assertEquals('token123', dto.nextPageToken);
    }

    // ============================================================
    //  COMMENT PAGE
    // ============================================================

    @isTest
    static void testToCommentPageWithPopulatedPage() {
        ConnectApi.CommentPage page = new ConnectApi.CommentPage();
        page.total = 2;
        page.nextPageToken = null;

        ConnectApi.Comment c1 = new ConnectApi.Comment();
        c1.id = '0D7' + '0000000000001';
        c1.createdDate = Datetime.now();
        c1.body = buildBody(new List<ConnectApi.MessageSegment>{
            buildTextSegment('Comment one')
        });

        ConnectApi.Comment c2 = new ConnectApi.Comment();
        c2.id = '0D7' + '0000000000002';
        c2.createdDate = Datetime.now();
        c2.body = buildBody(new List<ConnectApi.MessageSegment>{
            buildTextSegment('Comment two')
        });

        page.items = new List<ConnectApi.Comment>{ c1, c2 };

        ChatterCommentPageDto dto = ChatterDtoMapper.toCommentPage(page);

        System.assertEquals(2, dto.comments.size());
        System.assertEquals('Comment one', dto.comments[0].text);
        System.assertEquals('Comment two', dto.comments[1].text);
        System.assertEquals(2, dto.total);
    }

    // ============================================================
    //  COMMENT — PLAIN TEXT
    // ============================================================

    @isTest
    static void testToCommentPlainText() {
        ConnectApi.Comment c = new ConnectApi.Comment();
        c.id = '0D7' + '0000000000003';
        c.createdDate = Datetime.now();
        c.body = buildBody(new List<ConnectApi.MessageSegment>{
            buildTextSegment('A comment')
        });

        ChatterCommentDto dto = ChatterDtoMapper.toComment(c);

        System.assertEquals('0D7' + '0000000000003', dto.id);
        System.assertEquals('A comment', dto.text);
    }

    // ============================================================
    //  COMMENT — MARKUP
    // ============================================================

    @isTest
    static void testToCommentWithBoldMarkup() {
        ConnectApi.MarkupBeginSegment beginSeg = new ConnectApi.MarkupBeginSegment();
        beginSeg.markupType = ConnectApi.MarkupType.Bold;

        ConnectApi.MarkupEndSegment endSeg = new ConnectApi.MarkupEndSegment();
        endSeg.markupType = ConnectApi.MarkupType.Bold;

        ConnectApi.Comment c = new ConnectApi.Comment();
        c.id = '0D7' + '0000000000004';
        c.createdDate = Datetime.now();
        c.body = buildBody(new List<ConnectApi.MessageSegment>{
            beginSeg, buildTextSegment('bold comment'), endSeg
        });

        ChatterCommentDto dto = ChatterDtoMapper.toComment(c);

        System.assert(dto.text.contains('<b>'), 'Missing <b>. Got: ' + dto.text);
        System.assert(dto.text.contains('bold comment'), 'Missing content. Got: ' + dto.text);
    }

    // ============================================================
    //  BATCH HELPERS
    // ============================================================

    @isTest
    static void testEnrichCommentsEmpty() {
        List<ChatterCommentDto> results = ChatterDtoMapper.enrichComments(new List<String>());
        System.assertEquals(0, results.size());
    }

    @isTest
    static void testEnrichCommentsNull() {
        List<ChatterCommentDto> results = ChatterDtoMapper.enrichComments(null);
        System.assertEquals(0, results.size());
    }

    @isTest
    static void testEnrichFeedEditPermissionsEmpty() {
        Map<String, Boolean> results =
            ChatterDtoMapper.enrichFeedEditPermissions(new List<String>());
        System.assertEquals(0, results.size());
    }

    @isTest
    static void testEnrichFeedEditPermissionsNull() {
        Map<String, Boolean> results =
            ChatterDtoMapper.enrichFeedEditPermissions(null);
        System.assertEquals(0, results.size());
    }

    @isTest
    static void testLoadAttachmentsEmpty() {
        Map<String, List<ChatterAttachmentDto>> result =
            ChatterDtoMapper.loadAttachmentsForFeedElements(new List<String>());
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testLoadAttachmentsUnknownIds() {
        Map<String, List<ChatterAttachmentDto>> result =
            ChatterDtoMapper.loadAttachmentsForFeedElements(
                new List<String>{ '0D5' + '0000000000000' }
            );
        System.assertEquals(0, result.size());
    }

    // ============================================================
    //  BUILDERS
    // ============================================================

    private static ConnectApi.FeedItem buildFeedItem(String id) {
        ConnectApi.FeedItem item = new ConnectApi.FeedItem();
        item.id = id;
        item.createdDate = Datetime.now();
        item.feedElementType = ConnectApi.FeedElementType.FeedItem;
        return item;
    }

    private static ConnectApi.FeedBody buildBody(List<ConnectApi.MessageSegment> segs) {
        ConnectApi.FeedBody body = new ConnectApi.FeedBody();
        body.messageSegments = segs;
        return body;
    }

    private static ConnectApi.TextSegment buildTextSegment(String text) {
        ConnectApi.TextSegment seg = new ConnectApi.TextSegment();
        seg.text = text;
        return seg;
    }
}