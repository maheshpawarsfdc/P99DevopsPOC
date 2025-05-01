@isTest
private class CampaignEmailMetricsControllerTest {
    
    // Test setup method to create test data
    @testSetup
    static void setupTestData() {
        // Create test users - a manager and subordinate
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User manager = new User(
            FirstName = 'Test',
            LastName = 'Manager',
            Email = 'testmanager@example.com',
            Username = 'testmanager' + DateTime.now().getTime() + '@example.com',
            Alias = 'tmanager',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = p.Id
        );
        insert manager;
        
        User subordinate = new User(
            FirstName = 'Test',
            LastName = 'Subordinate',
            Email = 'testsubordinate@example.com',
            Username = 'testsubordinate' + DateTime.now().getTime() + '@example.com',
            Alias = 'tsubord',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = p.Id,
            ManagerId = manager.Id
        );
        insert subordinate;
        
        // Create test campaigns
        List<Campaign> campaigns = new List<Campaign>();
        
        System.runAs(manager) {
            campaigns.add(new Campaign(
                Name = 'Test Campaign 1',
                Type = 'Email',
                IsActive = true
            ));
            
            campaigns.add(new Campaign(
                Name = 'Test Campaign 2',
                Type = 'Conference',
                IsActive = true
            ));
        }
        
        System.runAs(subordinate) {
            campaigns.add(new Campaign(
                Name = 'Subordinate Campaign',
                Type = 'Email',
                IsActive = true
            ));
        }
        
        insert campaigns;
        
        // Create test leads
        List<Lead> leads = new List<Lead>();
        for(Integer i = 0; i < 20; i++) {
            Lead l = new Lead();
            l.FirstName = 'Test';
            l.LastName = 'Lead ' + i;
            l.Email = 'testlead' + i + '@example.com';
            l.Company = 'Test Company';
            
            // Set different email flags for different leads to test various scenarios
            if(i < 15) {
                l.IsFirstEmailSent__c = true;
            }
            if(i < 10) {
                l.IsFirstFollowUpSent__c = true;
            }
            if(i < 5) {
                l.IsSecondFollowUpSent__c = true;
            }
            if(i < 2) {
                l.IsThirdFollowUpSent__c = true;
            }
            
            leads.add(l);
        }
        insert leads;
        
        // Create campaign members
        List<CampaignMember> members = new List<CampaignMember>();
        
        // Add 20 leads to the first campaign
        for(Integer i = 0; i < 20; i++) {
            members.add(new CampaignMember(
                CampaignId = campaigns[0].Id,
                LeadId = leads[i].Id
            ));
        }
        
        // Add 10 leads to the second campaign
        for(Integer i = 0; i < 10; i++) {
            members.add(new CampaignMember(
                CampaignId = campaigns[1].Id,
                LeadId = leads[i].Id
            ));
        }
        
        // Add 5 leads to the third campaign
        for(Integer i = 0; i < 5; i++) {
            members.add(new CampaignMember(
                CampaignId = campaigns[2].Id,
                LeadId = leads[i].Id
            ));
        }
        
        insert members;
    }
    
    @isTest
    static void testGetCampaignEmailMetrics() {
        // Get the campaign to test with
        Campaign camp = [SELECT Id FROM Campaign WHERE Name = 'Test Campaign 1' LIMIT 1];
        
        Test.startTest();
        Map<String, Object> results = CampaignEmailMetricsController.getCampaignEmailMetrics(camp.Id);
        Test.stopTest();
        
        // Validate results
        System.assertEquals('Test Campaign 1', results.get('campaignName'), 'Campaign name should match');
        System.assertEquals('Email', results.get('campaignType'), 'Campaign type should match');
        System.assertEquals(20, results.get('totalLeads'), 'Total leads should be 20');
        System.assertEquals(15, results.get('firstEmailCount'), '15 leads should have first email sent');
        System.assertEquals(10, results.get('firstFollowUpCount'), '10 leads should have first follow-up sent');
        System.assertEquals(5, results.get('secondFollowUpCount'), '5 leads should have second follow-up sent');
        System.assertEquals(2, results.get('thirdFollowUpCount'), '2 leads should have third follow-up sent');
        
        // Check percentage calculations
        System.assertEquals(75.0, results.get('firstEmailPercentage'), 'First email percentage should be 75%');
        System.assertEquals(50.0, results.get('firstFollowUpPercentage'), 'First follow-up percentage should be 50%');
        System.assertEquals(25.0, results.get('secondFollowUpPercentage'), 'Second follow-up percentage should be 25%');
        System.assertEquals(10.0, results.get('thirdFollowUpPercentage'), 'Third follow-up percentage should be 10%');
        
        // Check conversion rates
        System.assertEquals(66.7, results.get('firstToFollowUpRate'), 'First to follow-up rate should be 66.7%');
        System.assertEquals(50.0, results.get('firstToSecondFollowUpRate'), 'First to second follow-up rate should be 50%');
        System.assertEquals(40.0, results.get('secondToThirdFollowUpRate'), 'Second to third follow-up rate should be 40%');
    }
    
    @isTest
    static void testGetCampaignEmailMetricsNoLeads() {
        // Create a campaign with no leads
        Campaign emptyCamp = new Campaign(
            Name = 'Empty Campaign',
            Type = 'Email',
            IsActive = true
        );
        insert emptyCamp;
        
        Test.startTest();
        Map<String, Object> results = CampaignEmailMetricsController.getCampaignEmailMetrics(emptyCamp.Id);
        Test.stopTest();
        
        // Validate results for empty campaign
        System.assertEquals('Empty Campaign', results.get('campaignName'), 'Campaign name should match');
        System.assertEquals('Email', results.get('campaignType'), 'Campaign type should match');
        System.assertEquals(0, results.get('totalLeads'), 'Total leads should be 0');
        System.assertEquals(0, results.get('firstEmailCount'), 'No leads should have first email sent');
        System.assertEquals(0, results.get('firstEmailPercentage'), 'First email percentage should be 0%');
        System.assertEquals(0, results.get('firstToFollowUpRate'), 'First to follow-up rate should be 0%');
    }
    
    @isTest
    static void testGetAllCampaignsEmailMetrics() {
        // Get the manager user
        User manager = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
        
        // Get date for filter (today)
        Date today = Date.today();
        
        Test.startTest();
        // Test getting all campaigns
        List<Map<String, Object>> allMetrics = CampaignEmailMetricsController.getAllCampaignsEmailMetrics(
            today.addDays(-1), // Yesterday
            today.addDays(1),  // Tomorrow
            null               // No user filter
        );
        
        // Test getting campaigns for specific user
        List<Map<String, Object>> managerMetrics = CampaignEmailMetricsController.getAllCampaignsEmailMetrics(
            today.addDays(-1), // Yesterday
            today.addDays(1),  // Tomorrow
            manager.Id         // Manager's campaigns
        );
        Test.stopTest();
        
        // Validate all campaigns results
        System.assertEquals(3, allMetrics.size(), 'Should return metrics for all 3 campaigns');
        
        // Validate manager's campaigns results
        //System.assertEquals(2, managerMetrics.size(), 'Should return metrics for 2 campaigns created by manager');
    }
    
    @isTest
    static void testGetAllCampaignsEmailMetricsNoResults() {
        // Test with dates that will not return any campaigns
        Date futureDate = Date.today().addYears(1);
        
        Test.startTest();
        List<Map<String, Object>> emptyMetrics = CampaignEmailMetricsController.getAllCampaignsEmailMetrics(
            futureDate,     // Future date
            futureDate.addDays(1),  // Future date + 1
            null            // No user filter
        );
        Test.stopTest();
        
        // Validate empty results
        System.assertEquals(0, emptyMetrics.size(), 'Should return empty list when no campaigns match criteria');
    }
    
    @isTest
    static void testGetUserAndHisSubordinates() {
        // Get the manager user
        User manager = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
        
        Test.startTest();
        // Test getting subordinates
        List<User> subordinates = CampaignEmailMetricsController.getUserAndHisSubordinates(manager.Id);
        
        // Test with empty ID
        List<User> emptyResult = CampaignEmailMetricsController.getUserAndHisSubordinates('');
        Test.stopTest();
        
        // Validate subordinates results
        System.assertEquals(1, subordinates.size(), 'Should return 1 subordinate user');
        
        // Re-query to get the full User records for validation
        List<Id> subordinateIds = new List<Id>();
        for(User u : subordinates) {
            subordinateIds.add(u.Id);
        }
        
        List<User> fullSubordinates = [SELECT Id, LastName FROM User WHERE Id IN :subordinateIds];
        System.assertEquals('Subordinate', fullSubordinates[0].LastName, 'Subordinate should be returned');
        
        // Validate empty ID results
        System.assertEquals(0, emptyResult.size(), 'Should return empty list when ID is blank');
    }
    
    @isTest
    static void testGetCampaignTypes() {
        Test.startTest();
        List<String> types = CampaignEmailMetricsController.getCampaignTypes();
        Test.stopTest();
        
        // Validate campaign types
        System.assert(!types.isEmpty(), 'Should return campaign type picklist values');
        
        // Check if the types used in our test data are included
        Boolean hasEmailType = false;
        Boolean hasConferenceType = false;
        
        for(String type : types) {
            if(type == 'Email') hasEmailType = true;
            if(type == 'Conference') hasConferenceType = true;
        }
        
        System.assert(hasEmailType || hasConferenceType, 'Should include standard campaign types');
    }
    
    @isTest
    static void testGetCampaignComparison() {
        // Get the campaigns to compare
        Campaign camp1 = [SELECT Id FROM Campaign WHERE Name = 'Test Campaign 1' LIMIT 1];
        Campaign camp2 = [SELECT Id FROM Campaign WHERE Name = 'Test Campaign 2' LIMIT 1];
        
        Test.startTest();
        Map<String, Object> comparison = CampaignEmailMetricsController.getCampaignComparison(camp1.Id, camp2.Id);
        Test.stopTest();
        
        // Validate comparison results
        System.assertNotEquals(null, comparison.get('firstCampaign'), 'First campaign metrics should be included');
        System.assertNotEquals(null, comparison.get('secondCampaign'), 'Second campaign metrics should be included');
        
        // Check difference calculations
        Map<String, Object> firstCampaignMetrics = (Map<String, Object>)comparison.get('firstCampaign');
        Map<String, Object> secondCampaignMetrics = (Map<String, Object>)comparison.get('secondCampaign');
        
        System.assertEquals(
            (Decimal)firstCampaignMetrics.get('firstEmailPercentage') - (Decimal)secondCampaignMetrics.get('firstEmailPercentage'),
            comparison.get('firstEmailDiff'),
            'First email difference should be calculated correctly'
        );
    }
    
    @isTest
    static void testExceptionHandling() {
        // Test with invalid ID to trigger exception
        String invalidId = '001000000000000AAA';
        
        Test.startTest();
        try {
            CampaignEmailMetricsController.getCampaignComparison(invalidId, invalidId);
            System.assert(false, 'Expected exception was not thrown');
        } catch (AuraHandledException e) {
            // This exception should be caught and rethrown as an AuraHandledException
            System.assert(true, 'Exception was properly caught and rethrown');
        }
        Test.stopTest();
    }
}