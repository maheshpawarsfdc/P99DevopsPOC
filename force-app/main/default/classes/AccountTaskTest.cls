@isTest
public class AccountTaskTest {
    @isTest
    public static void TestCreateTask(){
        //create new Account Record 
        
        Account testAccount = new Account(Name = 'Test Account',
                                          AccountNumber= '1234',
                                          
                                          // below field is mandatory in my personal org 
                                         Created_Date__c = system.today());
        insert testAccount ;
        
        // calling method to create task 
        AccountTaskClass.CreateTask(new List<Account>{testAccount});
        
        // Query for the Task
        List<Task> tasks = [SELECT Id, WhatId FROM Task WHERE WhatId = :testAccount.Id];
        
            // Assert that a Task was created for the Account
        System.assertEquals(1, tasks.size(), 'A Task should be created for the new Account');
        
        
    }

}