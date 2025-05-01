@IsTest
Global class GmailEmailServiceTest {

    // Inner class to implement HttpCalloutMock
    // This class must be GLOBAL because it has a GLOBAL method (respond),
    // but it does NOT need the @IsTest annotation.
    global class GmailApiMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        private String expectedNamedCredential; // To assert which named credential is used

        // Constructor to set the desired response and expected named credential
        public GmailApiMock(Integer statusCode, String responseBody, String expectedNamedCredential) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
            this.expectedNamedCredential = expectedNamedCredential;
        }

        global HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.responseBody);

            // Optional: Assert that the correct Named Credential is used
            System.assert(req.getEndpoint().contains('callout:' + this.expectedNamedCredential),
                          'Expected Named Credential ' + this.expectedNamedCredential + ' not found in endpoint: ' + req.getEndpoint());

            return res;
        }
    }

    // @IsTest
    // static void testSendEmailSuccessDefaultUser() {
    //     // Setup test data (User with signature, not maheshpawarsfdc@gmail.com)
    //     User testUser = new User(
    //         Alias = 'testu',
    //         Email = 'testuser@example.com',
    //         EmailEncodingKey = 'UTF-8',
    //         LastName = 'User',
    //         LanguageLocaleKey = 'en_US',
    //         LocaleSidKey = 'en_US',
    //         ProfileId = UserInfo.getProfileId(),
    //         Signature = 'Test User Signature',
    //         TimeZoneSidKey = 'GMT',
    //         Username = 'testuser' + System.currentTimeMillis() + '@example.com'
    //     );

    //     System.runAs(testUser) {
    //         // Set the mock callout for successful send and metadata fetch
    //         // Mock for send (POST)
    //         String sendResponseBody = '{"id": "mockEmailId123", "threadId": "mockThreadId456"}';
    //         Test.setMock(HttpCalloutMock.class, new GmailApiMock(200, sendResponseBody, 'Gmail_API'));

    //         Test.startTest();

    //         // Call the method to test
    //         Map<String, String> result = GmailEmailService.sendEmail(
    //             'recipient@example.com',
    //             'Test Subject',
    //             'This is the email body.'
    //         );

    //         Test.stopTest();

    //         // Assertions
    //         System.assertNotEquals(null, result, 'Result map should not be null');
    //         System.assertEquals('recipient@example.com', result.get('email'), 'Email address should match');
    //         System.assertEquals('mockThreadId456', result.get('threadId'), 'Thread ID should match mock response');
    //         System.assertEquals('Sent', result.get('status'), 'Status should be Sent');
    //         System.assertEquals('Test Subject', result.get('subject'), 'Subject should match');
    //     }
    // }

    //  @IsTest
    // static void testSendEmailSuccessMaheshUser() {
    //     // Setup test data for the specific user 'maheshpawarsfdc@gmail.com'
    //      User maheshUser = new User(
    //         Alias = 'mahesh',
    //         Email = 'maheshpawarsfdc@gmail.com',
    //         EmailEncodingKey = 'UTF-8',
    //         LastName = 'Pawar',
    //         LanguageLocaleKey = 'en_US',
    //         LocaleSidKey = 'en_US',
    //         ProfileId = UserInfo.getProfileId(),
    //         Signature = 'Mahesh Signature',
    //         TimeZoneSidKey = 'GMT',
    //         Username = 'maheshpawarsfdc@gmail.com' + System.currentTimeMillis()
    //     );

    //     System.runAs(maheshUser) {
    //         // Set the mock callout for successful send and metadata fetch
    //         // Mock for send (POST)
    //         String sendResponseBody = '{"id": "mockEmailIdMahesh", "threadId": "mockThreadIdMahesh"}';
    //         // Expect 'Gmail_API_2' for this user
    //         Test.setMock(HttpCalloutMock.class, new GmailApiMock(200, sendResponseBody, 'Gmail_API_2'));

    //         Test.startTest();

    //         // Call the method to test
    //         Map<String, String> result = GmailEmailService.sendEmail(
    //             'recipient@example.com',
    //             'Test Subject',
    //             'This is the email body for Mahesh.'
    //         );

    //         Test.stopTest();

    //         // Assertions
    //         System.assertNotEquals(null, result, 'Result map should not be null');
    //         System.assertEquals('recipient@example.com', result.get('email'), 'Email address should match');
    //         System.assertEquals('mockThreadIdMahesh', result.get('threadId'), 'Thread ID should match mock response');
    //         System.assertEquals('Sent', result.get('status'), 'Status should be Sent');
    //         System.assertEquals('Test Subject', result.get('subject'), 'Subject should match');

    //         // The GmailApiMock constructor includes an assertion to check if 'Gmail_API_2' was used.
    //     }
    // }


    @IsTest
    static void testSendEmailFailure() {
        // Setup test data (User with signature)
         User testUser = new User(
            Alias = 'testu2',
            Email = 'testuser2@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User2',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            Signature = 'Test User Signature 2',
            TimeZoneSidKey = 'GMT',
            Username = 'testuser2' + System.currentTimeMillis() + '@example.com'
        );

        System.runAs(testUser) {
            // Set a mock that returns an error status code (e.g., 500)
            String errorResponseBody = '{"error": "Internal Server Error"}';
             Test.setMock(HttpCalloutMock.class, new GmailApiMock(500, errorResponseBody, 'Gmail_API')); // Expect default API

            Test.startTest();

            // Call the method and assert that a System.CalloutException is thrown
            Boolean caughtException = false;
            try {
                GmailEmailService.sendEmail(
                    'recipient@example.com',
                    'Test Subject',
                    'This is the email body.'
                );
            } catch (System.CalloutException e) {
                caughtException = true;
                System.assert(e.getMessage().contains('Gmail API Error'), 'Exception message should indicate API error');
                System.assert(e.getMessage().contains(errorResponseBody), 'Exception message should contain the error body');
            }

            Test.stopTest();

            // Assert that the exception was caught
            System.assertEquals(true, caughtException, 'Should have caught a System.CalloutException');
        }
    }
}