@isTest
private class GmailCampaignServiceTest {
    
    // Test data setup method
    @TestSetup
    static void setupTestData() {
        // Create a test campaign
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign',
            IsActive = true
        );
        insert testCampaign;
        
        // Create email templates for different campaign types
        List<Email_Template__c> templates = new List<Email_Template__c>{
            new Email_Template__c(
                Name = 'Test Template 1',
                Subject__c = 'Test Subject 1',
                Email_Body__c = 'Hello {!Lead.FirstName}, welcome to {!Lead.Company}!',
                IsActive__c = true,
                Campaign_type__c = 'Campaign Email'
            ),
            new Email_Template__c(
                Name = 'Test Template 2',
                Subject__c = 'Test Subject 2',
                Email_Body__c = 'Hi {!Lead.Name}, this is a follow-up.',
                IsActive__c = true,
                Campaign_type__c = 'Campaign Email'
            )
        };
        insert templates;
        
        // Create test leads
        List<Lead> leads = new List<Lead>();
        for(Integer i = 0; i < 50; i++) {
            leads.add(new Lead(
                FirstName = 'Test' + i,
                LastName = 'Lead' + i,
                Company = 'Test Company ' + i,
                Email = 'testlead' + i + '@example.com',
                Title = 'Manager',
                City = 'Test City',
                Status__c = 'No Email Sent'
            ));
        }
        
        // Create some leads with different statuses for follow-up tests
        leads.add(new Lead(
            FirstName = 'Follow',
            LastName = 'Up1',
            Company = 'Follow Company',
            Email = 'followup1@example.com',
            Title = 'Director',
            City = 'Follow City',
            Status__c = 'Campaign Email Sent'
        ));
        
        leads.add(new Lead(
            FirstName = 'Follow',
            LastName = 'Up2',
            Company = 'Follow Company',
            Email = 'followup2@example.com',
            Title = 'VP',
            City = 'Follow City',
            Status__c = '1st Follow-Up Sent'
        ));
        
        insert leads;
        
        // Associate leads with the campaign
        List<CampaignMember> members = new List<CampaignMember>();
        for(Lead lead : leads) {
            members.add(new CampaignMember(
                CampaignId = testCampaign.Id,
                LeadId = lead.Id,
                Status = 'Sent'
            ));
        }
        insert members;
    }
    
    // @isTest
    // static void testGetEmailTemplates() {
    //     // Call the method being tested
    //     Test.startTest();
    //     List<Email_Template__c> outreachTemplates = GmailCampaignService.getEmailTemplates('Outreach');
    //     List<Email_Template__c> nurtureTemplates = GmailCampaignService.getEmailTemplates('Nurture');
    //     Test.stopTest();
        
    //     // Verify the results
    //     System.assertEquals(0, outreachTemplates.size(), 'Should return one Outreach template');
    //     System.assertEquals('Test Template 1', outreachTemplates[0].Name, 'Template name should match');
        
    //     System.assertEquals(1, nurtureTemplates.size(), 'Should return one Nurture template');
    //     System.assertEquals('Test Template 2', nurtureTemplates[0].Name, 'Template name should match');
    // }
    
    @isTest
    static void testGetTemplateDetails() {
        // Get a template ID
        Email_Template__c template = [SELECT Id FROM Email_Template__c WHERE Name = 'Test Template 1' LIMIT 1];
        
        // Call the method being tested
        Test.startTest();
        Map<String, String> details = GmailCampaignService.getTemplateDetails(template.Id);
        Test.stopTest();
        
        // Verify the results
        System.assertEquals('Test Subject 1', details.get('subject'), 'Subject should match');
        System.assertEquals('Hello {!Lead.FirstName}, welcome to {!Lead.Company}!', details.get('body'), 'Body should match');
    }
    
    @isTest
    static void testGetCampaignMembers_InitialEmail() {
        // Get campaign ID
        Campaign campaign = [SELECT Id FROM Campaign WHERE Name = 'Test Campaign' LIMIT 1];
        
        // Call the method being tested
        Test.startTest();
        List<Map<String, String>> members = GmailCampaignService.getCampaignMembers(campaign.Id, 'Campaign Email', true);
        Test.stopTest();
        
        // Verify results (should return leads with 'No Email Sent' status)
        System.assertNotEquals(0, members.size(), 'Should return campaign members');
        for(Map<String, String> member : members) {
            System.assert(member.containsKey('Email'), 'Should contain Email field');
            System.assert(member.containsKey('Name'), 'Should contain Name field');
        }
    }
    
    @isTest
    static void testGetCampaignMembers_FirstFollowUp() {
        // Get campaign ID
        Campaign campaign = [SELECT Id FROM Campaign WHERE Name = 'Test Campaign' LIMIT 1];
        
        // Call the method being tested
        Test.startTest();
        List<Map<String, String>> members = GmailCampaignService.getCampaignMembers(campaign.Id, '1st Follow-Up', true);
        Test.stopTest();
        
        // Verify results (should return leads with 'Campaign Email Sent' status)
        System.assertNotEquals(0, members.size(), 'Should return members for first follow-up');
        Boolean foundFollowUpLead = false;
        for(Map<String, String> member : members) {
            if(member.get('Email') == 'followup1@example.com') {
                foundFollowUpLead = true;
                break;
            }
        }
        System.assert(foundFollowUpLead, 'Should include lead with Campaign Email Sent status');
    }
    
    @isTest
    static void testGetCampaignMembers_SecondFollowUp() {
        // Get campaign ID
        Campaign campaign = [SELECT Id FROM Campaign WHERE Name = 'Test Campaign' LIMIT 1];
        
        // Call the method being tested
        Test.startTest();
        List<Map<String, String>> members = GmailCampaignService.getCampaignMembers(campaign.Id, '2nd Follow-Up', true);
        Test.stopTest();
        
        // Verify results (should return leads with '1st Follow-Up Sent' status)
        System.assertNotEquals(0, members.size(), 'Should return members for second follow-up');
        Boolean foundFollowUpLead = false;
        for(Map<String, String> member : members) {
            if(member.get('Email') == 'followup2@example.com') {
                foundFollowUpLead = true;
                break;
            }
        }
        System.assert(foundFollowUpLead, 'Should include lead with 1st Follow-Up Sent status');
    }
    
    @isTest
    static void testGetCampaignMembers_InactiveError() {
        // Get campaign ID
        Campaign campaign = [SELECT Id FROM Campaign WHERE Name = 'Test Campaign' LIMIT 1];
        
        // Update campaign to inactive
        campaign.IsActive = false;
        update campaign;
        
        // Call the method being tested, expect exception
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            List<Map<String, String>> members = GmailCampaignService.getCampaignMembers(campaign.Id, 'Campaign Email', false);
        } catch(AuraHandledException e) {
            exceptionThrown = true;
            System.assertEquals('Script-thrown exception', e.getMessage(), 'Error message should match');
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown for inactive campaign');
    }
    
    @isTest
    static void testGetCampaignMembers_EmptyTypeError() {
        // Get campaign ID
        Campaign campaign = [SELECT Id FROM Campaign WHERE Name = 'Test Campaign' LIMIT 1];
        
        // Call the method being tested with empty follow-up type, expect exception
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            List<Map<String, String>> members = GmailCampaignService.getCampaignMembers(campaign.Id, '', true);
        } catch(AuraHandledException e) {
            exceptionThrown = true;
            System.assertEquals('Script-thrown exception', e.getMessage(), 'Error message should match');
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown for empty follow-up type');
    }
    
    @isTest
    static void testGetCampaignMemberCount() {
        // Get campaign ID
        Campaign campaign = [SELECT Id FROM Campaign WHERE Name = 'Test Campaign' LIMIT 1];
        
        // Call the method being tested
        Test.startTest();
        Integer count = GmailCampaignService.getCampaignMemberCount(campaign.Id, 'Campaign Email');
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(0, count, 'Should return non-zero count');
    }
    
    @isTest
    static void testGetCampaignMemberCount_EmptyTypeError() {
        // Get campaign ID
        Campaign campaign = [SELECT Id FROM Campaign WHERE Name = 'Test Campaign' LIMIT 1];
        
        // Call the method with empty follow-up type, expect exception
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            Integer count = GmailCampaignService.getCampaignMemberCount(campaign.Id, '');
        } catch(AuraHandledException e) {
            exceptionThrown = true;
            System.assertEquals('Script-thrown exception', e.getMessage(), 'Error message should match');
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown for empty follow-up type');
    }
    
    @isTest
    static void testSendCampaignEmails() {
        // Create a mock for the GmailEmailService
        // Since we can't easily mock external service calls in Apex tests, we'll use Test.isRunningTest()
        // Typically, you would create a mock service class that implements an interface, but for this
        // test we'll assume GmailEmailService handles this internally
        
        // Get campaign and leads
        Campaign campaign = [SELECT Id FROM Campaign WHERE Name = 'Test Campaign' LIMIT 1];
        List<Lead> testLeads = [SELECT Id FROM Lead WHERE Status__c = 'No Email Sent' LIMIT 5];
        List<String> leadIds = new List<String>();
        for(Lead lead : testLeads) {
            leadIds.add(lead.Id);
        }
        
        // Call the method being tested
        Test.startTest();
        
        // Create a mock implementation or check using Test.isRunningTest() in the actual service
        // For this test, we'll assume this happens in GmailEmailService
        
        List<Map<String, String>> results = GmailCampaignService.sendCampaignEmails(
            campaign.Id,
            leadIds,
            'Test Subject {!Lead.FirstName}',
            'Hello {!Lead.Name}, this is a test from {!Lead.Company}.'
        );
        Test.stopTest();
        
        // Verify email tracking records were created (if not mocked)
        List<Email_Tracking__c> trackingRecords = [
            SELECT Id, Lead_Id__c, Status__c
            FROM Email_Tracking__c
            WHERE Campaign_Id__c = :campaign.Id
        ];
        
        // Check if leads were updated
        List<Lead> updatedLeads = [
            SELECT Id, Status__c
            FROM Lead
            WHERE Id IN :leadIds
        ];
        
        // If GmailEmailService.sendEmail is properly mocked or handles test mode, there should be results
        System.assertEquals(5, results.size(), 'Should return results for each lead');
    }
    
    @isTest
    static void testSendCampaignEmails_NoValidRecipients() {
        // Get campaign
        Campaign campaign = [SELECT Id FROM Campaign WHERE Name = 'Test Campaign' LIMIT 1];
        
        // Get leads with wrong status
        List<Lead> testLeads = [SELECT Id FROM Lead WHERE Status__c = 'Campaign Email Sent' LIMIT 5];
        List<String> leadIds = new List<String>();
        for(Lead lead : testLeads) {
            leadIds.add(lead.Id);
        }
        
        // Call the method, expect exception
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            List<Map<String, String>> results = GmailCampaignService.sendCampaignEmails(
                campaign.Id,
                leadIds,
                'Test Subject',
                'Test Body'
            );
        } catch(AuraHandledException e) {
            exceptionThrown = true;
            System.assertEquals('Script-thrown exception', e.getMessage(), 'Error message should match');
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown for invalid recipients');
    }
    
    @isTest
    static void testReplaceMergeFields() {
        // Prepare test data
        String template = 'Hello {!Lead.FirstName} {!Lead.LastName} from {!Lead.Company}!';
        Map<String, String> mergeFields = new Map<String, String>{
            '{!Lead.FirstName}' => 'John',
            '{!Lead.LastName}' => 'Doe',
            '{!Lead.Company}' => 'Acme Inc'
        };
        
        // Call the method being tested
        Test.startTest();
        String result = GmailCampaignService.replaceMergeFields(template, mergeFields);
        Test.stopTest();
        
        // Verify the result
        System.assertEquals('Hello John Doe from Acme Inc!', result, 'Merge fields should be replaced correctly');
    }
    
    @isTest
    static void testRetrieveSalesforceUser() {
        // Call the method being tested
        Test.startTest();
        User result = GmailCampaignService.retrieveSalesforceUser();
        Test.stopTest();
        
        // Verify the result
        System.assertNotEquals(null, result, 'Should return current user');
        System.assertEquals(UserInfo.getUserId(), result.Id, 'Should return current user ID');
    }
    
    
}