public class AccountTaskClass {
    public static void CreateTask (list<Account> Acclist){
        // created list to insert multiple task in one transaction
        list<Task> NewTaskList = new List<Task>();
        
        // check Acclist is not empty
        if(!Acclist.isEmpty()){
            for(Account Acc:Acclist){
                
                //create one task associate with one account record
            Task newTask = new Task();
            newTask.WhatId =acc.id;
            newTask.subject = 'Review Account - ' + acc.AccountNumber;
            newTask.Description = 'Please Review this new Account  ' ;
            newTask.OwnerId = acc.OwnerId ;
            newTask.Status = 'Not Started';
            newTask.ActivityDate = System.today().addDays(7);
            newTask.Priority = 'Normal' ;
            
                
                //add task to list 
            NewTaskList.add(newTask) ;
            
           
        }
        }
        
       if(!NewTaskList.isEmpty()) {
        
            insert NewTaskList; // Insert all Tasks in one DML operation
      
    }
        
        
    }

}