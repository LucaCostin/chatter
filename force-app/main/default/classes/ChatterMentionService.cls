public with sharing class ChatterMentionService {

    private static final Integer DEFAULT_LIMIT = 8;
    private static final Integer MAX_LIMIT     = 25;

    @AuraEnabled(cacheable=true)
    public static List<ChatterMentionDto> search(String term, Integer limitSize) {
        if (String.isBlank(term)) return new List<ChatterMentionDto>();

        Integer lim = clamp(limitSize);
        String pattern = '%' + String.escapeSingleQuotes(term.trim()) + '%';
        List<ChatterMentionDto> out = new List<ChatterMentionDto>();

        // Users — no community filter. Standard Chatter shows all active users.
        // WITH USER_MODE enforces field-level security.
        for (User u : [
            SELECT Id, Name, SmallPhotoUrl, Title
            FROM User
            WHERE IsActive = true
              AND Name LIKE :pattern
              AND UserType IN ('Standard', 'PowerPartner',
                               'PowerCustomerSuccess', 'CustomerSuccess',
                               'CSPLitePortal', 'CsnOnly')
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT :lim
        ]) {
            ChatterMentionDto d = new ChatterMentionDto();
            d.id = u.Id; d.name = u.Name; d.photoUrl = u.SmallPhotoUrl;
            d.type = 'User'; d.subtitle = u.Title;
            out.add(d);
        }

        // Groups — community-scoped when in a community
        String communityId = ChatterCommunityContext.getCommunityId();
        List<CollaborationGroup> groups;
        if (String.isNotBlank(communityId)) {
            groups = [
                SELECT Id, Name, SmallPhotoUrl, Description
                FROM CollaborationGroup
                WHERE NetworkId = :communityId AND Name LIKE :pattern
                WITH USER_MODE
                ORDER BY Name ASC
                LIMIT :lim
            ];
        } else {
            groups = [
                SELECT Id, Name, SmallPhotoUrl, Description
                FROM CollaborationGroup
                WHERE Name LIKE :pattern
                WITH USER_MODE
                ORDER BY Name ASC
                LIMIT :lim
            ];
        }
        for (CollaborationGroup g : groups) {
            ChatterMentionDto d = new ChatterMentionDto();
            d.id = g.Id; d.name = g.Name; d.photoUrl = g.SmallPhotoUrl;
            d.type = 'Group'; d.subtitle = g.Description;
            out.add(d);
        }

        if (out.size() > lim) {
            List<ChatterMentionDto> trimmed = new List<ChatterMentionDto>();
            for (Integer i = 0; i < lim; i++) trimmed.add(out[i]);
            return trimmed;
        }
        return out;
    }

    private static Integer clamp(Integer requested) {
        if (requested == null) return DEFAULT_LIMIT;
        if (requested < 1) return 1;
        if (requested > MAX_LIMIT) return MAX_LIMIT;
        return requested;
    }
}