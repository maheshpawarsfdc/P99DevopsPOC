global class CheckEmailRepliesBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Schedulable {
    
    // Maximum number of callouts per transaction
    private static final Integer MAX_CALLOUTS = 90;
    private static String NAMED_CREDENTIAL;
    
    global void execute(SchedulableContext ctx) {
        // Start the batch process when scheduled
        Database.executeBatch(new CheckEmailRepliesBatch(), MAX_CALLOUTS);
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        // Query for all records that need checking
        return Database.getQueryLocator([
            SELECT Id, Status__c, Lead_Id__c, Campaign_Id__c, Next_Follow_up_Date__c, 
                   Recipient_Email__c, Thread_ID__c 
            FROM Email_Tracking__c 
            WHERE Status__c != 'Replied' 
            AND Next_Follow_up_Date__c <= :System.Now()
            AND (Last_Reply_Check__c = null OR Last_Reply_Check__c < :System.now().addMinutes(-30))
            ORDER BY Last_Reply_Check__c NULLS FIRST
        ]);
    }
    
    global void execute(Database.BatchableContext BC, List<Email_Tracking__c> scope) {
        // First, extract thread IDs and other data - NO DML YET
        Map<String, String> threadIdStatusMap = new Map<String, String>();
        Map<String, Id> threadIdToRecordId = new Map<String, Id>();
        
        for (Email_Tracking__c email : scope) {
            if (String.isNotBlank(email.Thread_ID__c)) {
                threadIdStatusMap.put(email.Thread_ID__c, email.Status__c);
                threadIdToRecordId.put(email.Thread_ID__c, email.Id);
            }
        }
        
        // Set up the named credential for API calls
        String username = [SELECT Username
                         FROM User 
                         WHERE Id = :UserInfo.getUserId() 
                         LIMIT 1].Username;
        
        NAMED_CREDENTIAL = (username == 'maheshpawarsfdc@gmail.com') ? 'Gmail_API_2' : 'Gmail_API';
        System.debug('Named Credential: ' + NAMED_CREDENTIAL);
        
        // Process email threads - make ALL callouts BEFORE any DML execution
        Map<String, Boolean> threadReplies = new Map<String, Boolean>();
        
        // Process each thread ID - the batch size ensures we don't exceed callout limits
        for (String threadId : threadIdStatusMap.keySet()) {
            String status = threadIdStatusMap.get(threadId);
            Boolean hasReply = checkSingleThread(threadId, status);
            threadReplies.put(threadId, hasReply);
        }
        
        // AFTER all callouts are complete, now we can do DML operations
        
        // First, update Last_Reply_Check__c for all records in scope
        List<Email_Tracking__c> allRecordsToUpdate = new List<Email_Tracking__c>();
        for (Email_Tracking__c email : scope) {
            Email_Tracking__c updatedRecord = new Email_Tracking__c(
                Id = email.Id,
                Last_Reply_Check__c = System.now()
            ); 
            
            // ONLY update the Status to 'Replied' if the thread has a reply
            if (String.isNotBlank(email.Thread_ID__c) && 
                threadReplies.containsKey(email.Thread_ID__c) && 
                threadReplies.get(email.Thread_ID__c) == true) {
                updatedRecord.Status__c = 'Replied';
                System.debug('Marking email record ' + email.Id + ' with thread ' + email.Thread_ID__c + ' as Replied');
            }
            
            allRecordsToUpdate.add(updatedRecord);
        }
        
        // Single DML operation AFTER all callouts
        if (!allRecordsToUpdate.isEmpty()) {
            update allRecordsToUpdate;
            
            // Log for debugging
            Integer repliedCount = 0;
            for (Email_Tracking__c email : allRecordsToUpdate) {
                if (email.Status__c == 'Replied') {
                    repliedCount++;
                }
            }
            System.debug('Updated ' + allRecordsToUpdate.size() + ' total records. Marked ' + repliedCount + ' as replied.');
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        // Nothing to do in the finish method
    }
    
    // Check a single thread with Gmail API
    private Boolean checkSingleThread(String threadId, String status) {
        if (String.isEmpty(threadId)) {
            System.debug('Thread ID is empty, skipping check.');
            return false;
        }
    
        // Construct the Gmail API endpoint
        String endpoint = 'callout:' + NAMED_CREDENTIAL + '/gmail/v1/users/me/threads/' + threadId;
    
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
    
        Http http = new Http();
        HttpResponse res;
        
        try {
            res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Parse response JSON
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    
                if (responseMap.containsKey('messages')) {
                    List<Object> messages = (List<Object>) responseMap.get('messages');
                    System.debug('Messages for thread ' + threadId + ': ' + messages.size());
    
                    // Check message count based on status
                    if (messages.size() > 3 && status == '2nd Follow-Up Sent') {
                        System.debug('Reply detected in 3rd followup thread ID: ' + threadId);
                        return true;
                    } else if(messages.size() > 2 && status == '1st Follow-Up Sent'){
                        System.debug('Reply detected in 2nd followup thread ID: ' + threadId);
                        return true;
                    } else if(messages.size() > 1 && status == 'Sent'){
                        System.debug('Reply detected in 1st followup thread ID: ' + threadId);
                        return true;
                    }
                }
            } else {
                System.debug('Error fetching thread ' + threadId + ': ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception when checking thread ' + threadId + ': ' + e.getMessage());
        }
        
        return false;
    }
}