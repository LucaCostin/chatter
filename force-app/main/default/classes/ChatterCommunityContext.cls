public with sharing class ChatterCommunityContext {
    private static String  cachedCommunityId;
    private static Boolean resolved = false;

    public static String getCommunityId() {
        if (!resolved) {
            try { cachedCommunityId = Network.getNetworkId(); }
            catch (Exception e) { cachedCommunityId = null; }
            resolved = true;
        }
        return cachedCommunityId;
    }
}