public with sharing class GmailThreadCheck {
    private static String NAMED_CREDENTIAL;

    @future(callout=true)
    public static void checkGmailThreads(Map<String,String> threadIdsToStatusMap) {
            
        String username = [SELECT Id,Username
        FROM User 
        WHERE Id = :UserInfo.getUserId() 
        LIMIT 1].Username;
        
       NAMED_CREDENTIAL = (username == 'maheshpawarsfdc@gmail.com') ? 'Gmail_API_2':'Gmail_API';
        // Map to store thread ID to reply status
        Map<String, Boolean> threadReplies = new Map<String, Boolean>();
        
        // Process each thread ID
        for (String threadId : threadIdsToStatusMap.keySet()) {
            String status = threadIdsToStatusMap.get(threadId);
            System.debug('Status inside Gmail thread check:'+status);
            Boolean hasReply = checkSingleThread(threadId,status);
            threadReplies.put(threadId, hasReply);
        }
        
        // Now update the records
        updateEmailStatuses(threadReplies);
    }


    private static Boolean checkSingleThread(String threadId,String status) {
        if (String.isEmpty(threadId)) {
            System.debug('Thread ID is empty, skipping check.');
            return false;
        }
    
        // Construct the Gmail API endpoint to get messages in the thread
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
    
                    // If the thread contains more than 1 message, a reply exists
                    if (messages.size() > 3 && status == '2nd Follow-Up Sent') {
                        System.debug('Reply detected in 3rd followup thread ID: ' + threadId);
                        return true;
                    }else if(messages.size() > 2 && status == '1st Follow-Up Sent'){
                        System.debug('Reply detected in 2nd followup thread ID: ' + threadId);
                        return true;
                    }else if(messages.size() > 1 && status == 'Sent'){
                        System.debug('Reply detected in 1st followup thread ID: ' + threadId);
                        return true;
                    }

                     //  Based on status and messages size , we will check different conditions for 1st followup , 2nd followup , 3rd followup
                }
            } else {
                System.debug('Error fetching thread ' + threadId + ': ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception when checking thread ' + threadId + ': ' + e.getMessage());
        }
        
        return false;
    }


    private static void updateEmailStatuses(Map<String, Boolean> threadReplies) {
        // Query for email records with these thread IDs
        List<Email_Tracking__c> emailsToUpdate = [
            SELECT Id, Status__c, Thread_ID__c
            FROM Email_Tracking__c
            WHERE Thread_ID__c IN :threadReplies.keySet()
            AND Status__c != 'Replied'
        ];
        
        List<Email_Tracking__c> updatedEmails = new List<Email_Tracking__c>();
        
        for (Email_Tracking__c email : emailsToUpdate) {
            Boolean hasReply = threadReplies.get(email.Thread_ID__c);
            String status = email.Status__c;
            if (hasReply) {
                email.Status__c = 'Replied';
                updatedEmails.add(email);
            }
        }
        
        if (!updatedEmails.isEmpty()) {
            try {
                update updatedEmails;
                System.debug('Updated ' + updatedEmails.size() + ' email records to Replied status.');
            } catch (Exception e) {
                System.debug('Error updating email records: ' + e.getMessage());
            }
        }
    }
}