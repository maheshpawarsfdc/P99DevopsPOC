public class FollowUpEmailService {
    private static String NAMED_CREDENTIAL;

    @AuraEnabled
    public static List<Map<String, String>> sendCustomFollowUpEmails(String campaignId, String followUpType, String customBody, List<String> selectedLeadIds) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        List<Email_Tracking__c> emailsToUpdate = new List<Email_Tracking__c>();
        // Query email tracking records based on selected leads or all eligible leads if none selected
        String query = 'SELECT Id, Recipient_Email__c, Subject__c, Thread_ID__c, Message_ID__c, Lead_Id__c, ' +
                      'Campaign_Id__c, Next_Follow_up_Date__c, Status__c ' +
                      'FROM Email_Tracking__c ' +
                      'WHERE Campaign_Id__c = :campaignId AND Status__c != \'Replied\'';
        // Add lead filter if specific leads are selected
        if (selectedLeadIds != null && !selectedLeadIds.isEmpty()) {
            query += ' AND Lead_Id__c IN :selectedLeadIds';
        }
        // Add status filter based on follow-up type
        if (followUpType == '1st-Follow Up') {
            query += ' AND Status__c = \'Sent\'';
        } else if (followUpType == '2nd-Follow Up') {
            query += ' AND Status__c = \'1st Follow-Up Sent\'';
        } else if (followUpType == '3rd-Follow Up') {
            query += ' AND Status__c = \'2nd Follow-Up Sent\'';
        }
        List<Email_Tracking__c> emailsToFollowUp = Database.query(query);
        if (emailsToFollowUp.isEmpty()) {
            throw new AuraHandledException('No eligible emails found for follow-up.');
        }
        // Query leads to get merge field data
        Set<Id> leadIds = new Set<Id>();
        for (Email_Tracking__c email : emailsToFollowUp) {
            if (email.Lead_Id__c != null) {
                leadIds.add(email.Lead_Id__c);
            }
        }
        Map<Id, Lead> leadsMap = new Map<Id, Lead>([
            SELECT Id, Name, FirstName, LastName, Email, Company, Title, City
            FROM Lead
            WHERE Id IN :leadIds
        ]);
        // Send follow-ups for each email
        for (Email_Tracking__c email : emailsToFollowUp) {
            Map<String, String> result = new Map<String, String>();
            result.put('Email', email.Recipient_Email__c);
            // Skip if missing required fields
            if (String.isEmpty(email.Thread_ID__c) || String.isEmpty(email.Message_ID__c)) {
                result.put('Status', 'Failed: Missing Thread ID or Message ID');
                results.add(result);
                continue;
            }
            try {
                // Prepare personalized content if lead exists
                String personalizedBody = customBody;
                Lead lead = leadsMap.get(email.Lead_Id__c);
                if (lead != null) {
                    // Prepare merge fields
                    Map<String, String> mergeFields = new Map<String, String>{
                        '{!Lead.Name}' => lead.Name != null ? lead.Name : '',
                        '{!Lead.Company}' => lead.Company != null ? lead.Company : '',
                        '{!Lead.LastName}' => lead.LastName != null ? lead.LastName : '',
                        '{!Lead.FirstName}' => lead.FirstName != null ? lead.FirstName : '',
                        '{!Lead.Email}' => lead.Email != null ? lead.Email : '',
                        '{!Lead.Title}' => lead.Title != null ? lead.Title : '',
                        '{!Lead.City}' => lead.City != null ? lead.City : ''
                    };
                    result.put('Name', lead.Name);
                    personalizedBody = GmailCampaignService.replaceMergeFields(customBody, mergeFields);

                    system.debug('Personalized content: ' + personalizedBody);
                }
                // Construct subject
                String followUpSubject = 'Re: ' + email.Subject__c;
                // Send follow-up email
                
                String newStatus = sendFollowUp(email, followUpSubject, personalizedBody);
                result.put('Status', 'Success: ' + newStatus);
                // Update email status based on follow-up type
                if (followUpType == '1st-Follow Up') {
                    email.Status__c = '1st Follow-Up Sent';
                    // Update lead field
                    if (lead != null) {
                        lead.IsFirstFollowUpSent__c = true;
                    }
                } else if (followUpType == '2nd-Follow Up') {
                    email.Status__c = '2nd Follow-Up Sent';
                    if (lead != null) {
                        lead.IsSecondFollowUpSent__c = true;
                    }
                } else if (followUpType == '3rd-Follow Up') {
                    email.Status__c = '3rd Follow-Up Sent';
                    if (lead != null) {
                        lead.IsThirdFollowUpSent__c = true;
                    }
                }
                // Set next follow-up date based on hours
                Integer hoursToAdd = 0;
                if (followUpType == '1st-Follow Up') {
                    hoursToAdd = 72; // 3 days (120-48) for 2nd follow-up
                } else if (followUpType == '2nd-Follow Up') {
                    hoursToAdd = 120; // 5 days (240-120) for 3rd follow-up
                }
                if (hoursToAdd > 0) {
                    email.Next_Follow_up_Date__c = System.now().addHours(hoursToAdd);
                }
                emailsToUpdate.add(email);
            } catch (Exception e) {
                result.put('Status', 'Failed: ' + e.getMessage());
            }
            results.add(result);
        }
        // Update email tracking records
        if (!emailsToUpdate.isEmpty()) {
            try {
                update emailsToUpdate;
                // Update lead records
                if (!leadsMap.isEmpty()) {
                    update leadsMap.values();
                }
            } catch (Exception e) {
                System.debug('Error updating records: ' + e.getMessage());
            }
        }
        return results;
    }

    private static String sendFollowUp(Email_Tracking__c email, String subject, String body) {
        // Retrieve the Salesforce user signature
        String username = '';
        User userDetail= GmailCampaignService.retrieveSalesforceUser();
        if(userDetail != null){
             username = userDetail.Username;
        }
        System.debug('username::'+username);
        NAMED_CREDENTIAL = (username == 'dhananjay.mane@p99soft.com') ? 'D_GmailApi':'Gmail_API';
            System.debug('Named Credential::' +NAMED_CREDENTIAL);

        String fullEmailBody='<div>' +
                          body +
                       '</div>';

        // Construct email headers for threading
        String emailHeaders = 'To: ' + email.Recipient_Email__c + '\r\n' +
                              'Subject: =?UTF-8?B?' + EncodingUtil.base64Encode(Blob.valueOf(subject)) + '?=\r\n' +
                              'In-Reply-To: ' + email.Message_ID__c + '\r\n' + // Links follow-up email to the original
                              'References: ' + email.Message_ID__c + '\r\n' +  // Keeps email in the thread
                              'MIME-Version: 1.0\r\n' +
                              'Content-Type: text/html; charset="UTF-8"\r\n\r\n' +
                              fullEmailBody;
        // Encode email in Base64 URL-safe format (required by Gmail API)
        String encodedEmail = EncodingUtil.base64Encode(Blob.valueOf(emailHeaders))
                              .replace('+', '-').replace('/', '_');
        // Construct JSON payload
        String jsonBody = '{"raw": "' + encodedEmail + '", "threadId": "' + email.Thread_ID__c + '"}';
        // Construct Gmail API endpoint
        String endpoint = 'callout:' + NAMED_CREDENTIAL + '/gmail/v1/users/me/messages/send';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200 || res.getStatusCode() == 202) {
            System.debug('Follow-up email sent successfully to ' + email.Recipient_Email__c);
            return 'Follow-up sent';
        } else {
            System.debug('Follow-up email failed: ' + res.getBody());
            throw new System.CalloutException('Gmail API Error: ' + res.getBody());
        }
    }
    
}