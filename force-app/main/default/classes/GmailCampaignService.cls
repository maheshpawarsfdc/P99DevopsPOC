public with sharing class GmailCampaignService {
    // Maximum emails to process in a single transaction
    private static final Integer MAX_EMAILS_PER_BATCH = 40;
    
    @AuraEnabled(cacheable=true)
    public static List<Email_Template__c> getEmailTemplates(String campaigntype) {
        return [
            SELECT Id, Name, Subject__c 
            FROM Email_Template__c 
            WHERE IsActive__c = true 
            AND Campaign_type__c = :campaigntype
            ORDER BY Name ASC
        ];
    }

    // Get template details method remains the same
    @AuraEnabled
    public static Map<String, String> getTemplateDetails(String templateId) {
        // Existing implementation...
        Email_Template__c template = [
            SELECT Id, Name, Subject__c, Email_Body__c 
            FROM Email_Template__c 
            WHERE Id = :templateId 
            LIMIT 1
        ];

        Map<String, String> templateDetails = new Map<String, String>();
        templateDetails.put('subject', template.Subject__c);
        templateDetails.put('body', template.Email_Body__c);
        
        return templateDetails;
    }
    
    // Updated campaign members query to use Follow_Up_Status__c picklist
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCampaignMembers(Id campaignId, String followUpType, Boolean isActive) {
        if (String.isEmpty(followUpType)) {
            throw new AuraHandledException('Error: Follow-up type cannot be empty.');
        } else if(!isActive) {
            throw new AuraHandledException('Campaign must be approved by your manager to start campaigning!');
        }

        // Map follow-up types to corresponding lead statuses
        String requiredStatus = getRequiredLeadStatus(followUpType);
        
        // Build the dynamic WHERE clause
        String whereClause = 'WHERE Id IN (SELECT LeadId FROM CampaignMember WHERE CampaignId = :campaignId) AND Email != NULL';
        
        // Add status condition based on follow-up type
        if (followUpType == 'Campaign Email') {
            whereClause += ' AND Status__c = \'No Email Sent\'';
        } else {
            String previousStatus = getPreviousFollowUpStatus(followUpType);
            whereClause += ' AND Status__c = \'' + previousStatus + '\'';
        }

        // Construct final SOQL query
        String queryString = 'SELECT Id, FirstName, LastName, Title, Name, Email, Company, City, Status__c ' 
                        + 'FROM Lead ' + whereClause + ' ORDER BY Name LIMIT 40';

        // Execute query dynamically
        List<Lead> members = Database.query(queryString);
         
        List<Map<String, String>> membersList = new List<Map<String, String>>();
        for (Lead member : members) {
            Map<String, String> memberMap = new Map<String, String>();
            memberMap.put('Id', member.Id);
            memberMap.put('FirstName', member.FirstName);
            memberMap.put('LastName', member.LastName);
            memberMap.put('Name', member.Name);
            memberMap.put('Email', member.Email);
            memberMap.put('Company', member.Company);
            memberMap.put('Title', member.Title);
            memberMap.put('City', member.City);
            membersList.add(memberMap);
        }
        
        return membersList;
    }

    // Updated to use Follow_Up_Status__c picklist
    @AuraEnabled(cacheable=true)
    public static Integer getCampaignMemberCount(Id campaignId, String followUpType) {
        if (String.isEmpty(followUpType)) {
            throw new AuraHandledException('Error: Follow-up type cannot be empty.');
        }

        // Build the dynamic WHERE clause
        String whereClause = 'WHERE Id IN (SELECT LeadId FROM CampaignMember WHERE CampaignId = :campaignId) AND Email != NULL';
        
        // Add status condition based on follow-up type
        if (followUpType == 'Campaign Email') {
            whereClause += ' AND Status__c	 = \'No Email Sent\'';
        } else {
            String previousStatus = getPreviousFollowUpStatus(followUpType);
            whereClause += ' AND Status__c = \'' + previousStatus + '\'';
        }

        // Execute the optimized SOQL query
        return Database.countQuery('SELECT COUNT() FROM Lead ' + whereClause);
    }

    // Helper to get the required lead status for a given follow-up type
    private static String getRequiredLeadStatus(String followUpType) {
        if (followUpType == 'Campaign Email') {
            return 'No Email Sent';
        }
        
        // Extract the follow-up number and return the corresponding status
        Integer followUpNum = getFollowUpNumber(followUpType);
        return (followUpNum > 0) ? followUpNum + getOrdinalSuffix(followUpNum) + ' Follow-Up Sent' : 'Campaign Email Sent';
    }
    
    // Helper to get the previous status for a given follow-up type
    private static String getPreviousFollowUpStatus(String followUpType) {
        if (followUpType == 'Campaign Email') {
            return 'No Email Sent';
        }
        
        Integer followUpNum = getFollowUpNumber(followUpType);
        if (followUpNum == 1) {
            return 'Campaign Email Sent';
        } else if (followUpNum > 1) {
            return (followUpNum - 1) + getOrdinalSuffix(followUpNum - 1) + ' Follow-Up Sent';
        }
        
        return 'No Email Sent';
    }

    // Helper to extract the follow-up number from the type string
    private static Integer getFollowUpNumber(String followUpType) {
        if (followUpType == 'Campaign Email') {
            return 0;
        }
        
        Pattern p = Pattern.compile('^(\\d+)');
        Matcher m = p.matcher(followUpType);
        if (m.find()) {
            return Integer.valueOf(m.group(1));
        }
        return 0;
    }

    // Helper to get ordinal suffix
    private static String getOrdinalSuffix(Integer i) {
        Integer j = Math.mod(i, 10);
        Integer k = Math.mod(i, 100);
        
        if (j == 1 && k != 11) {
            return 'st';
        }
        if (j == 2 && k != 12) {
            return 'nd';
        }
        if (j == 3 && k != 13) {
            return 'rd';
        }
        return 'th';
    }

    // Updated to use Follow_Up_Status__c picklist
    @AuraEnabled
    public static List<Map<String, String>> sendCampaignEmails(Id campaignId, List<String> selectedLeadIds, String subject, String body) {
        // Get the selected leads
        List<Lead> leads = [
            SELECT Id, FirstName, LastName, Title, Name, Email, Company, City, Status__c
            FROM Lead 
            WHERE Id IN :selectedLeadIds
            AND Email != NULL 
            AND Status__c = 'No Email Sent'
        ];
        
        if (leads.isEmpty()) {
            throw new AuraHandledException('No valid recipients found.');
        }
        
        // Process emails
        return sendEmailsImmediately(leads, subject, body, campaignId);
    }
    
    private static List<Map<String, String>> sendEmailsImmediately(List<Lead> leads, String subject, String body, String campaignId) {
        // Retrieve the current user's signature
        User currentUser = [
            SELECT Id, Email, Signature 
            FROM User 
            WHERE Id = :UserInfo.getUserId() 
            LIMIT 1
        ];

        // Append signature to the body if it exists
        String emailBodyWithSignature = body;
        if (String.isNotBlank(currentUser.Signature)) {
            emailBodyWithSignature += '<br><br>' + currentUser.Signature;
        }

        List<Map<String, String>> results = new List<Map<String, String>>();
        List<Lead> leadsToUpdate = new List<Lead>();
        List<Email_Tracking__c> emailTrackingList = new List<Email_Tracking__c>();
        
        for (Lead lead : leads) {
            Map<String, String> result = new Map<String, String>();
            
            system.debug('Lead Details: ' + lead.Name + ', ' + lead.FirstName + ', ' + lead.Title + ', ' + lead.City);
        
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
            result.put('Email', lead.Email);
            
            // Generate personalized content
            String personalizedSubject = replaceMergeFields(subject, mergeFields);
            String personalizedBody = replaceMergeFields(body, mergeFields);
        
            // Populate result map
            result.putAll(mergeFields);
        
            try {
                Map<String,String> EmailSuccessTrack = GmailEmailService.sendEmail(lead.Email, personalizedSubject, personalizedBody);
                result.put('Status', 'Sent');
        
                // Update lead follow-up status
                lead.Status__c = 'Campaign Email Sent';
                leadsToUpdate.add(lead);
                
                // Set next follow-up time
                Datetime futureTime = System.now().addHours(48); // 2 days for first follow-up
                
                emailTrackingList.add(new Email_Tracking__c(
                    Message_ID__c = EmailSuccessTrack.get('msgId'),
                    Recipient_Email__c = EmailSuccessTrack.get('email'),
                    Status__c = 'Campaign Email Sent',
                    Thread_ID__c = EmailSuccessTrack.get('threadId'), 
                    Subject__c = EmailSuccessTrack.get('subject'),
                    Lead_Id__c = lead.Id,
                    Campaign_Id__c = campaignId, 
                    Next_Follow_up_Date__c = futureTime
                ));
            } catch (Exception e) {
                system.debug('Failed to send email to: ' + lead.Email + ' - Error: ' + e.getMessage());
                result.put('Status', 'Failed: ' + e.getMessage().left(100));
            }
        
            results.add(result);
        }
        
        // Insert tracking records
        if (!emailTrackingList.isEmpty()) {
            try {
                insert emailTrackingList;
            } catch (Exception e) {
                System.debug('Error creating emailTrackingRecords: ' + e.getMessage());
            }
        }

        // Update leads
        if (!leadsToUpdate.isEmpty()) {
            try {
                update leadsToUpdate;
            } catch (Exception e) {
                System.debug('Error updating leads: ' + e.getMessage());
            }
        }
        
        return results;
    }

    // Helper method for replacing merge fields - remains the same
    public static String replaceMergeFields(String template, Map<String, String> mergeFields) {
        for (String key : mergeFields.keySet()) {
            template = template.replace(key, mergeFields.get(key));
        }
        return template;
    }

    @AuraEnabled
    public static User retrieveSalesforceUser() {
        // Get the current user
        User currentUser = [
            SELECT Id, Username, Email, Signature 
            FROM User 
            WHERE Id = :UserInfo.getUserId() 
            LIMIT 1
        ];
        return currentUser;
    }
}