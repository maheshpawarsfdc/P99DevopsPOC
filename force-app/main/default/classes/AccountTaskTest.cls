@isTest
private class AccountTaskTest {
    
    @isTest
    static void testCreateTask_withAccounts() {
        // Create test data
        List<Account> testAccounts = new List<Account>();
        
        // Create test user to be the owner of the accounts
        User testUser = createTestUser();
        
        System.runAs(testUser) {
            // Create multiple test accounts
            for(Integer i = 0; i < 5; i++) {
                Account acc = new Account(
                    Name = 'Test Account ' + i,
                    AccountNumber = 'ACC-' + i,
                    OwnerId = testUser.Id
                );
                testAccounts.add(acc);
            }
            
            // Insert test accounts
            insert testAccounts;
            
            // Start the test
            Test.startTest();
            
            // Call the method to test
            AccountTaskClass.CreateTask(testAccounts);
            
            // Stop the test
            Test.stopTest();
            
            // Verify results
            List<Task> createdTasks = [SELECT Id, WhatId, Subject, Description, OwnerId, Status, ActivityDate, Priority 
                                       FROM Task 
                                       WHERE WhatId IN :testAccounts];
            
            // Assert that the correct number of tasks were created
            System.assertEquals(testAccounts.size(), createdTasks.size(), 'The number of tasks created should match the number of accounts');
            
            // Assert that each task has the correct values
            for(Task task : createdTasks) {
                // Find the corresponding account
                Account relatedAccount;
                for(Account acc : testAccounts) {
                    if(acc.Id == task.WhatId) {
                        relatedAccount = acc;
                        break;
                    }
                }
                
                // Verify task values
                System.assertNotEquals(null, relatedAccount, 'Task should be related to an account');
                System.assertEquals('Review Account - ' + relatedAccount.AccountNumber, task.Subject, 'Task subject should match expected format');
                System.assertEquals('Please Review this new Account', task.Description, 'Task description should match expected value');
                System.assertEquals(relatedAccount.OwnerId, task.OwnerId, 'Task owner should match account owner');
                System.assertEquals('Not Started', task.Status, 'Task status should be "Not Started"');
                System.assertEquals(System.today().addDays(7), task.ActivityDate, 'Task due date should be 7 days from today');
                System.assertEquals('Normal', task.Priority, 'Task priority should be "Normal"');
            }
        }
    }
    
    @isTest
    static void testCreateTask_emptyList() {
        // Test with empty list
        List<Account> emptyAccounts = new List<Account>();
        
        // Start the test
        Test.startTest();
        
        // Call the method with empty list
        AccountTaskClass.CreateTask(emptyAccounts);
        
        // Stop the test
        Test.stopTest();
        
        // Verify no tasks were created
        List<Task> createdTasks = [SELECT Id FROM Task];
        System.assertEquals(0, createdTasks.size(), 'No tasks should be created when account list is empty');
    }
    
    // Helper method to create a test user
    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        String uniqueUsername = 'testuser' + DateTime.now().getTime() + '@testorg.com';
        
        User u = new User(
            Alias = 'tuser',
            Email = 'testuser@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = uniqueUsername
        );
        
        insert u;
        return u;
    }
}