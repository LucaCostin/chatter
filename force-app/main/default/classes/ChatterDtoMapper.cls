public with sharing class ChatterDtoMapper {

    // ============================================================
    //  FEED
    // ============================================================

    public static ChatterFeedPageDto toFeedPage(ConnectApi.FeedElementPage page) {
        ChatterFeedPageDto dto = new ChatterFeedPageDto();
        if (page == null) return dto;

        dto.nextPageToken = page.nextPageToken;
        if (page.elements == null) return dto;

        String me = UserInfo.getUserId();
        List<String> elementIds = new List<String>();

        for (ConnectApi.FeedElement el : page.elements) {
            ChatterFeedElementDto d = toFeedElement(el, me);
            dto.elements.add(d);
            elementIds.add(d.id);
        }

        Map<String, List<ChatterAttachmentDto>> attachmentsByElementId =
            loadAttachmentsForFeedElements(elementIds);

        for (ChatterFeedElementDto d : dto.elements) {
            List<ChatterAttachmentDto> atts = attachmentsByElementId.get(d.id);
            if (atts != null && !atts.isEmpty()) {
                d.attachments = atts;
            }
        }

        return dto;
    }

    public static ChatterFeedElementDto toFeedElement(ConnectApi.FeedElement el, String currentUserId) {
        ChatterFeedElementDto d = new ChatterFeedElementDto();
        if (el == null) return d;

        d.id              = el.id;
        d.createdDate     = formatDate(el.createdDate);
        d.url             = el.url;
        d.feedElementType = el.feedElementType == null ? null : String.valueOf(el.feedElementType);

        if (el.body != null && el.body.messageSegments != null) {
            FlattenedText result = segmentsToHtml(el.body.messageSegments);
            d.text         = result.text;
            d.inlineImages = result.images;
        }
        if (String.isBlank(d.text) && el.header != null && String.isNotBlank(el.header.text)) {
            d.text = el.header.text;
        }

        if (el instanceof ConnectApi.FeedItem) {
            ConnectApi.FeedItem fi = (ConnectApi.FeedItem) el;
            if (fi.actor != null) {
                d.actorName = fi.actor.name;
                if (fi.actor instanceof ConnectApi.ActorWithId) {
                    d.actorId = ((ConnectApi.ActorWithId) fi.actor).id;
                }
            }
            d.actorPhoto = relativePhotoUrl(fi.photoUrl);
            d.canDelete  = fi.isDeleteRestricted == false;
        }

        if (el.capabilities != null) {
            applyFeedCapabilities(d, el.capabilities);
        }

        if (String.isNotBlank(d.actorId) && d.actorId == currentUserId) {
            d.canEdit = true;
        }
        return d;
    }

    private static void applyFeedCapabilities(
        ChatterFeedElementDto d,
        ConnectApi.FeedElementCapabilities caps
    ) {
        if (caps.chatterLikes != null) {
            d.currentUserLike = caps.chatterLikes.isLikedByCurrentUser == true;
            if (caps.chatterLikes.page != null && caps.chatterLikes.page.total != null) {
                d.likeCount = caps.chatterLikes.page.total;
            }
            if (caps.chatterLikes.myLike != null) {
                d.myLikeId = caps.chatterLikes.myLike.id;
            }
        }
        if (caps.comments != null && caps.comments.page != null
            && caps.comments.page.total != null) {
            d.commentCount = caps.comments.page.total;
        }
        if (caps.bookmarks != null) {
            d.isBookmarked = caps.bookmarks.isBookmarkedByCurrentUser == true;
        }
        if (caps.edit != null) {
            d.canEdit = caps.edit.isEditRestricted == false;
        }
    }

    // ============================================================
    //  COMMENTS
    // ============================================================

    public static ChatterCommentPageDto toCommentPage(ConnectApi.CommentPage page) {
        ChatterCommentPageDto dto = new ChatterCommentPageDto();
        if (page == null) return dto;

        dto.nextPageToken = page.nextPageToken;
        dto.total         = page.total == null ? 0 : page.total;

        if (page.items == null) return dto;

        String me = UserInfo.getUserId();
        for (ConnectApi.Comment c : page.items) {
            dto.comments.add(toComment(c, me));
        }
        return dto;
    }

    public static ChatterCommentDto toComment(ConnectApi.Comment c, String currentUserId) {
        ChatterCommentDto d = new ChatterCommentDto();
        if (c == null) return d;

        d.id          = c.id;
        d.createdDate = formatDate(c.createdDate);
        d.url         = c.url;

        if (c.user != null) {
            d.authorName = c.user.name;
            d.authorId   = c.user.id;
            if (c.user.photo != null) {
                d.authorPhoto = relativePhotoUrl(c.user.photo.smallPhotoUrl);
            }
        }

        if (c.body != null && c.body.messageSegments != null) {
            FlattenedText result = segmentsToHtml(c.body.messageSegments);
            d.text         = result.text;
            d.inlineImages = result.images;
        }

        // Likes — direct properties on Comment
        if (c.likes != null && c.likes.total != null) {
            d.likeCount = c.likes.total;
        }
        if (c.myLike != null && String.isNotBlank(c.myLike.id)) {
            d.currentUserLike = true;
            d.myLikeId        = c.myLike.id;
        }

        // Edit
        if (c.capabilities != null && c.capabilities.edit != null) {
            d.canEdit = c.capabilities.edit.isEditRestricted == false;
        }
        if (String.isNotBlank(d.authorId) && d.authorId == currentUserId) {
            d.canEdit = true;
        }

        // Delete — direct property on Comment
        d.canDelete = c.isDeleteRestricted == false;

        // File attachment
        if (c.capabilities != null && c.capabilities.content != null) {
            ConnectApi.ContentCapability cc = c.capabilities.content;
            ChatterAttachmentDto a = new ChatterAttachmentDto();
            a.id    = cc.id;
            a.title = cc.title;
            if (String.isNotBlank(cc.id)) {
                a.url = '/sfsites/c/sfc/servlet.shepherd/document/download/' + cc.id;
            }
            d.attachments.add(a);
        }

        if (c.parent != null) {
            d.parentId = c.parent.id;
        }

        return d;
    }

    public static ChatterCommentDto toComment(ConnectApi.Comment c) {
        return toComment(c, UserInfo.getUserId());
    }

    public static ChatterFeedElementDto toFeedElement(ConnectApi.FeedElement el) {
        ChatterFeedElementDto d = toFeedElement(el, UserInfo.getUserId());
        Map<String, List<ChatterAttachmentDto>> m =
            loadAttachmentsForFeedElements(new List<String>{ d.id });
        List<ChatterAttachmentDto> atts = m.get(d.id);
        if (atts != null) d.attachments = atts;
        return d;
    }

    // ============================================================
    //  ATTACHMENT LOADING
    // ============================================================

    public static Map<String, List<ChatterAttachmentDto>> loadAttachmentsForFeedElements(
        List<String> feedElementIds
    ) {
        Map<String, List<ChatterAttachmentDto>> result =
            new Map<String, List<ChatterAttachmentDto>>();

        if (feedElementIds == null || feedElementIds.isEmpty()) return result;

        List<FeedAttachment> links = [
            SELECT Id, FeedEntityId, RecordId, Type
            FROM FeedAttachment
            WHERE FeedEntityId IN :feedElementIds
              AND Type = 'Content'
        ];
        if (links.isEmpty()) return result;

        Set<Id> cvIds = new Set<Id>();
        Map<String, List<String>> cvIdsByElementId = new Map<String, List<String>>();
        for (FeedAttachment fa : links) {
            if (fa.RecordId == null) continue;
            cvIds.add(fa.RecordId);
            if (!cvIdsByElementId.containsKey(fa.FeedEntityId)) {
                cvIdsByElementId.put(fa.FeedEntityId, new List<String>());
            }
            cvIdsByElementId.get(fa.FeedEntityId).add(fa.RecordId);
        }
        if (cvIds.isEmpty()) return result;

        Map<Id, ContentVersion> cvById = new Map<Id, ContentVersion>([
            SELECT Id, ContentDocumentId, Title, FileExtension, FileType, ContentSize
            FROM ContentVersion
            WHERE Id IN :cvIds
        ]);

        for (String elementId : cvIdsByElementId.keySet()) {
            List<ChatterAttachmentDto> atts = new List<ChatterAttachmentDto>();
            for (String cvId : cvIdsByElementId.get(elementId)) {
                ContentVersion cv = cvById.get(cvId);
                if (cv == null) continue;
                atts.add(cvToAttachment(cv));
            }
            if (!atts.isEmpty()) result.put(elementId, atts);
        }
        return result;
    }

    private static ChatterAttachmentDto cvToAttachment(ContentVersion cv) {
        ChatterAttachmentDto a = new ChatterAttachmentDto();
        a.id               = cv.ContentDocumentId;
        a.contentVersionId = cv.Id;
        a.title            = cv.Title;
        a.fileExtension    = cv.FileExtension;
        a.mimeType         = cv.FileType;
        if (cv.ContentSize != null) {
            a.fileSize = Integer.valueOf(cv.ContentSize);
        }
        a.url = '/sfsites/c/sfc/servlet.shepherd/document/download/' + cv.ContentDocumentId;
        return a;
    }

    // ============================================================
    //  HELPERS
    // ============================================================

    private static String formatDate(Datetime dt) {
        return dt == null ? null : dt.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    private static String relativePhotoUrl(String url) {
        if (String.isBlank(url)) return null;

        String path = url;
        if (url.startsWith('http')) {
            Integer pathStart = url.indexOf('/', 8);
            if (pathStart < 0) return url;
            path = url.substring(pathStart);
        }

        if (path.startsWith('/sfsites/c/')) return path;
        if (path.startsWith('/profilephoto/')
            || path.startsWith('/services/images/')
            || path.startsWith('/c/')) {
            return '/sfsites/c' + path;
        }
        return path;
    }

    private class FlattenedText {
        String text = '';
        List<ChatterInlineImageDto> images = new List<ChatterInlineImageDto>();
    }

    private static FlattenedText segmentsToHtml(List<ConnectApi.MessageSegment> segs) {
        FlattenedText r = new FlattenedText();
        if (segs == null) return r;

        List<String> parts = new List<String>();
        Integer imgIdx = 0;

        for (ConnectApi.MessageSegment s : segs) {
            if (s instanceof ConnectApi.MarkupBeginSegment) {
                ConnectApi.MarkupBeginSegment m = (ConnectApi.MarkupBeginSegment) s;
                parts.add(openTag(m.markupType));

            } else if (s instanceof ConnectApi.MarkupEndSegment) {
                ConnectApi.MarkupEndSegment m = (ConnectApi.MarkupEndSegment) s;
                parts.add(closeTag(m.markupType));

            } else if (s instanceof ConnectApi.TextSegment) {
                ConnectApi.TextSegment t = (ConnectApi.TextSegment) s;
                if (t.text != null) parts.add(escapeHtml(t.text));

            } else if (s instanceof ConnectApi.MentionSegment) {
                ConnectApi.MentionSegment m = (ConnectApi.MentionSegment) s;
                if (m.record != null) {
                    parts.add('{' + m.record.id + '|' + escapeHtml(m.record.name) + '}');
                }

            } else if (s instanceof ConnectApi.LinkSegment) {
                ConnectApi.LinkSegment l = (ConnectApi.LinkSegment) s;
                if (String.isNotBlank(l.url)) {
                    String safeUrl = escapeHtml(l.url);
                    parts.add('<a href="' + safeUrl + '" target="_blank" rel="noopener">' + safeUrl + '</a>');
                }

            } else if (s instanceof ConnectApi.HashtagSegment) {
                ConnectApi.HashtagSegment h = (ConnectApi.HashtagSegment) s;
                if (String.isNotBlank(h.tag)) {
                    String safeTag = escapeHtml(h.tag);
                    parts.add('<a href="/search/' + safeTag + '">#' + safeTag + '</a>');
                }

            } else if (s instanceof ConnectApi.InlineImageSegment) {
                ConnectApi.InlineImageSegment img = (ConnectApi.InlineImageSegment) s;
                ChatterInlineImageDto d = new ChatterInlineImageDto();
                d.altText = img.altText;
                if (img.thumbnails != null && String.isNotBlank(img.thumbnails.fileId)) {
                    d.contentVersionId = img.thumbnails.fileId;
                    d.url              = '/sfsites/c/sfc/servlet.shepherd/document/download/' + img.thumbnails.fileId;
                    d.thumbnailUrl     = d.url;
                }
                d.position = imgIdx;
                r.images.add(d);
                parts.add('[[IMG:' + imgIdx + ']]');
                imgIdx++;
            }
        }

        r.text = String.join(parts, '');
        return r;
    }

    private static String openTag(ConnectApi.MarkupType type) {
        String t = String.valueOf(type);
        if (t == 'Bold')          return '<b>';
        if (t == 'Italic')        return '<i>';
        if (t == 'Underline')     return '<u>';
        if (t == 'Strikethrough') return '<s>';
        if (t == 'Paragraph')     return '<p>';
        if (t == 'UnorderedList') return '<ul>';
        if (t == 'OrderedList')   return '<ol>';
        if (t == 'ListItem')      return '<li>';
        if (t == 'Code')          return '<code>';
        return '';
    }

    private static String closeTag(ConnectApi.MarkupType type) {
        String t = String.valueOf(type);
        if (t == 'Bold')          return '</b>';
        if (t == 'Italic')        return '</i>';
        if (t == 'Underline')     return '</u>';
        if (t == 'Strikethrough') return '</s>';
        if (t == 'Paragraph')     return '</p>';
        if (t == 'UnorderedList') return '</ul>';
        if (t == 'OrderedList')   return '</ol>';
        if (t == 'ListItem')      return '</li>';
        if (t == 'Code')          return '</code>';
        return '';
    }

    private static String escapeHtml(String s) {
        if (String.isBlank(s)) return '';
        return s.replace('&', '&amp;')
                .replace('<', '&lt;')
                .replace('>', '&gt;')
                .replace('"', '&quot;')
                .replace('\'', '&#39;');
    }
}