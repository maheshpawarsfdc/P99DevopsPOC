@isTest
private class GmailAuthServiceTest {
    
    // Mock class for successful HTTP response
    private class MockHttpResponseSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"access_token":"mock_access_token_123456","token_type":"Bearer","expires_in":3600}');
            return response;
        }
    }
    
    // Mock class for failed HTTP response
    private class MockHttpResponseFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(400);
            response.setBody('{"error":"invalid_request","error_description":"Bad Request"}');
            return response;
        }
    }
    
    // Mock class for HTTP response with missing token
    private class MockHttpResponseMissingToken implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"token_type":"Bearer","expires_in":3600}');
            return response;
        }
    }
    
    // Test successful token retrieval
    @isTest
    static void testGetAccessTokenSuccess() {
        // Set mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        // Call the method
        Test.startTest();
        String accessToken = GmailAuthService.getAccessToken();
        Test.stopTest();
        
        // Verify the results
        System.assertEquals('mock_access_token_123456', accessToken, 'Access token should match the mock response');
    }
    
    // Test failed token retrieval due to HTTP error
    @isTest
    static void testGetAccessTokenHttpError() {
        // Set mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseFailure());
        
        // Call the method and expect an exception
        Test.startTest();
        try {
            GmailAuthService.getAccessToken();
            System.assert(false, 'Expected CalloutException was not thrown');
        } catch (System.CalloutException e) {
            System.assertEquals('Unable to get access token from Named Credential', e.getMessage(), 
                               'Exception message should match expected error');
        }
        Test.stopTest();
    }
    
    // Test failed token retrieval due to missing token in response
    @isTest
    static void testGetAccessTokenMissingToken() {
        // Set mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseMissingToken());
        
        // Call the method and expect an exception
        Test.startTest();
        try {
            GmailAuthService.getAccessToken();
            System.assert(false, 'Expected CalloutException was not thrown');
        } catch (System.CalloutException e) {
            System.assertEquals('Unable to get access token from Named Credential', e.getMessage(), 
                               'Exception message should match expected error');
        }
        Test.stopTest();
    }
    
    // Test the request format
    @isTest
    static void testRequestFormat() {
        // Custom mock to inspect the request
        MockHttpCalloutChecker mock = new MockHttpCalloutChecker();
        Test.setMock(HttpCalloutMock.class, mock);
        
        // Call the method but catch the exception since we're not returning a valid response
        Test.startTest();
        try {
            GmailAuthService.getAccessToken();
        } catch (Exception e) {
            // Expected exception - we're just checking the request
        }
        Test.stopTest();
        
        // Verify the request was properly formatted
        System.assertEquals('GET', mock.request.getMethod(), 'HTTP method should be GET');
        System.assertEquals('application/json', mock.request.getHeader('Content-Type'), 'Content-Type header should be application/json');
        System.assertEquals('callout:Gmail_API/oauth2/token', mock.request.getEndpoint(), 'Endpoint should match the expected format');
    }
    
    // Custom mock to inspect the HTTP request
    private class MockHttpCalloutChecker implements HttpCalloutMock {
        public HttpRequest request;
        
        public HttpResponse respond(HttpRequest req) {
            this.request = req;
            
            // Return a fake response
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setBody('{"error":"test_error"}');
            return response;
        }
    }
}