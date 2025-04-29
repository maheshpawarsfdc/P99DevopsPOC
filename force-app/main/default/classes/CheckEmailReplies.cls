global class CheckEmailReplies implements Schedulable {
    global void execute(SchedulableContext ctx) {
        // Collect all Thread IDs to check
        List<Email_Tracking__c> sentEmails = [
            SELECT Id, Status__c,Lead_Id__c,Campaign_Id__c,Next_Follow_up_Date__c, Recipient_Email__c, Thread_ID__c 
            FROM Email_Tracking__c 
            WHERE Status__c != 'Replied' AND Next_Follow_up_Date__c <= :System.Now() LIMIT 90
        ];
        
        // Extract thread IDs to check
        //Set<String> threadIds = new Set<String>();      // Instead of set , we will use Map<String,String> for (ThreadId,Status)
        Map<String,String> threadIdStatusMap = new Map<String,String>();
        for (Email_Tracking__c email : sentEmails) {
            if (String.isNotBlank(email.Thread_ID__c)) {
                //threadIds.add(email.Thread_ID__c);          // need to use map of put ThreadId, Status   

                threadIdStatusMap.put(email.Thread_ID__c, email.Status__c);
            }
        }
        
        // Start the asynchronous process
        if (!threadIdStatusMap.isEmpty()) {
            // GmailThreadCheck.checkGmailThreads(threadIds);   // call with  params but  Map(tId,Status)
            GmailThreadCheck.checkGmailThreads(threadIdStatusMap);
        }
    }
}