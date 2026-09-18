@isTest
private class ChatterExceptionTest {

    @isTest
    static void testSecurityFactory() {
        ChatterException e = ChatterException.security('test message');
        System.assertEquals('test message', e.getMessage(), 'Message should pass through');
    }

    @isTest
    static void testValidationFactory() {
        ChatterException e = ChatterException.validation('invalid');
        System.assertEquals('invalid', e.getMessage());
    }

    @isTest
    static void testNotFoundFactory() {
        ChatterException e = ChatterException.notFound('missing');
        System.assertEquals('missing', e.getMessage());
    }

    @isTest
    static void testUnknownFactory() {
        ChatterException e = ChatterException.unknown('mystery');
        System.assertEquals('mystery', e.getMessage());
    }

    @isTest
    static void testFromConnectWithMessage() {
        System.DmlException cause = new System.DmlException();
        ChatterException e = ChatterException.fromConnect(cause);
        System.assertNotEquals(null, e.getMessage(), 'Should produce a message from cause');
    }

    @isTest
    static void testFromConnectWithNull() {
        ChatterException e = ChatterException.fromConnect(null);
        System.assertEquals('Unknown Connect error', e.getMessage(),
            'Null cause should produce default message');
    }
}