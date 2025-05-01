@isTest
private class GmailThreadCheckTest {

    // Mock class to simulate Gmail API response
    class MockGmailThreadResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            // Simulate thread messages
            String mockBody = '{"messages": [ {}, {}, {}, {} ]}'; // 4 messages, reply detected
            res.setBody(mockBody);
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // Create sample user
        User testUser = [SELECT Id, Username FROM User WHERE Username != null LIMIT 1];

        // Create sample email tracking records
        List<Email_Tracking__c> emails = new List<Email_Tracking__c>();

        emails.add(new Email_Tracking__c(
            Thread_ID__c = 'test_thread_1',
            Status__c = 'Campaign Email Sent'
        ));

        emails.add(new Email_Tracking__c(
            Thread_ID__c = 'test_thread_2',
            Status__c = '1st Follow-Up Sent'
        ));

        emails.add(new Email_Tracking__c(
            Thread_ID__c = 'test_thread_3',
            Status__c = '2nd Follow-Up Sent'
        ));

        insert emails;
    }

    // @isTest
    // static void testCheckGmailThreads() {
    //     // Set mock response
    //     Test.setMock(HttpCalloutMock.class, new MockGmailThreadResponse());

    //     // Get test email records
    //     List<Email_Tracking__c> emails = [SELECT Id, Thread_ID__c, Status__c FROM Email_Tracking__c];

    //     // Prepare thread map input
    //     Map<String, String> threadMap = new Map<String, String>();
    //     for (Email_Tracking__c email : emails) {
    //         threadMap.put(email.Thread_ID__c, email.Status__c);
    //     }

    //     Test.startTest();
    //     GmailThreadCheck.checkGmailThreads(threadMap);
    //     Test.stopTest(); // Waits for @future to complete

    //     // Validate status update
    //     List<Email_Tracking__c> updatedEmails = [
    //         SELECT Id, Status__c FROM Email_Tracking__c
    //     ];

    //     for (Email_Tracking__c email : updatedEmails) {
    //         System.assertEquals('Replied', email.Status__c, 'Status should be updated to Replied');
    //     }
    // }

    @isTest
    static void testCheckGmailThreadsWithEmptyThread() {
        Test.setMock(HttpCalloutMock.class, new MockGmailThreadResponse());

        // Case with empty thread ID
        Map<String, String> threadMap = new Map<String, String>{
            '' => 'Sent'
        };

        Test.startTest();
        GmailThreadCheck.checkGmailThreads(threadMap);
        Test.stopTest();

        // Since no valid thread, nothing should be updated
        List<Email_Tracking__c> emails = [SELECT Id, Status__c FROM Email_Tracking__c];
        for (Email_Tracking__c email : emails) {
            System.assertNotEquals('', email.Status__c);
        }
    }
}