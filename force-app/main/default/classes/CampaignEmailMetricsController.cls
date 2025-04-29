public class CampaignEmailMetricsController {
    @AuraEnabled
    public static Map<String, Object> getCampaignEmailMetrics(Id campaignId) {
        Map<String, Object> results = new Map<String, Object>();
        
        // Query for the campaign
        Campaign camp = [SELECT Id, Name, Type FROM Campaign WHERE Id = :campaignId];
        
        // Get all leads associated with this campaign through CampaignMember
        List<Id> leadIds = new List<Id>();
        for(CampaignMember cm : [SELECT LeadId FROM CampaignMember 
                                 WHERE CampaignId = :campaignId AND LeadId != null]) {
            leadIds.add(cm.LeadId);
        }
        
        // Handle the case when no leads are found
        Integer totalLeads = leadIds.size();
        
        // Count each type of email sent - handle empty lead list
        Integer firstEmailCount = 0;
        Integer firstFollowUpCount = 0;
        Integer secondFollowUpCount = 0;
        Integer thirdFollowUpCount = 0;
        
        if(!leadIds.isEmpty()) {
            firstEmailCount = [SELECT COUNT() FROM Lead 
                              WHERE Id IN :leadIds AND IsFirstEmailSent__c = true];
            
            firstFollowUpCount = [SELECT COUNT() FROM Lead 
                                 WHERE Id IN :leadIds AND IsFirstFollowUpSent__c = true];
            
            secondFollowUpCount = [SELECT COUNT() FROM Lead 
                                  WHERE Id IN :leadIds AND IsSecondFollowUpSent__c = true];
            
            thirdFollowUpCount = [SELECT COUNT() FROM Lead 
                                 WHERE Id IN :leadIds AND IsThirdFollowUpSent__c = true];
        }
        
        // Add metrics to results
        results.put('campaignName', camp.Name);
        results.put('campaignType', camp.Type);
        results.put('totalLeads', totalLeads);
        results.put('firstEmailCount', firstEmailCount);
        results.put('firstFollowUpCount', firstFollowUpCount);
        results.put('secondFollowUpCount', secondFollowUpCount);
        results.put('thirdFollowUpCount', thirdFollowUpCount);
        
        // Calculate percentage values for progress bars
        results.put('firstEmailPercentage', totalLeads > 0 ? ((Decimal)firstEmailCount / totalLeads * 100).setScale(1) : 0);
        results.put('firstFollowUpPercentage', totalLeads > 0 ? ((Decimal)firstFollowUpCount / totalLeads * 100).setScale(1) : 0);
        results.put('secondFollowUpPercentage', totalLeads > 0 ? ((Decimal)secondFollowUpCount / totalLeads * 100).setScale(1) : 0);
        results.put('thirdFollowUpPercentage', totalLeads > 0 ? ((Decimal)thirdFollowUpCount / totalLeads * 100).setScale(1) : 0);
        
        // Calculate conversion rates between stages
        if (firstEmailCount > 0) {
            results.put('firstToFollowUpRate', 
                        ((Decimal)firstFollowUpCount / firstEmailCount * 100).setScale(1));
        } else {
            results.put('firstToFollowUpRate', 0);
        }
        
        if (firstFollowUpCount > 0) {
            results.put('firstToSecondFollowUpRate', 
                        ((Decimal)secondFollowUpCount / firstFollowUpCount * 100).setScale(1));
        } else {
            results.put('firstToSecondFollowUpRate', 0);
        }
        
        if (secondFollowUpCount > 0) {
            results.put('secondToThirdFollowUpRate', 
                        ((Decimal)thirdFollowUpCount / secondFollowUpCount * 100).setScale(1));
        } else {
            results.put('secondToThirdFollowUpRate', 0);
        }
        
        return results;
    }
    
    @AuraEnabled
    public static List<Map<String, Object>> getAllCampaignsEmailMetrics(Date startDate, Date endDate, String userId) {
        List<Map<String, Object>> allCampaignsMetrics = new List<Map<String, Object>>();
        
        // Query active campaigns
        List<Campaign> activeCampaigns;
        
        // Create end of day timestamp for the end date
        Datetime endOfDay = null;

        // If endDate is provided, set endOfDay to the last moment of that date (23:59:59)
        // This ensures we include all records/events occurring throughout the entire day,
        // especially useful for accurate date range comparisons or SOQL filtering.

        if(endDate != null) {
            endOfDay = Datetime.newInstance(endDate.year(), endDate.month(), endDate.day(), 23, 59, 59);
        }
        
        try {
            // Build the query based on provided filters
            String query = 'SELECT Id, Name FROM Campaign WHERE isActive = true';
            
            if(startDate != null) {
                query += ' AND CreatedDate >= :startDate';
            }
            
            if(endOfDay != null) {
                query += ' AND CreatedDate <= :endOfDay';
            }
            
            if(String.isNotBlank(userId)) {
                query += ' AND CreatedById = :userId';
            }
            
            activeCampaigns = Database.query(query);
            
            // Return early if no campaigns found
            if(activeCampaigns.isEmpty()) {
                return allCampaignsMetrics;
            }
                
            // Fetch metrics for these campaigns
            for(Campaign camp : activeCampaigns) {
                allCampaignsMetrics.add(getCampaignEmailMetrics(camp.Id));
            }
        } catch(Exception e) {
            System.debug('Error in getAllCampaignsEmailMetrics: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
        
        return allCampaignsMetrics;
    }

    @AuraEnabled
    public static List<User> getUserAndHisSubordinates(String userid){
        try {
            if(String.isBlank(userid)) {
                return new List<User>();
            }
            
            // Query to find direct subordinates
            List<User> userList = [SELECT Id, Name FROM User WHERE ManagerId = :userid AND IsActive = true];
            return userList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<String> getCampaignTypes() {
        try {
            Schema.DescribeFieldResult fieldResult = Campaign.Type.getDescribe();
            List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
            List<String> types = new List<String>();
            
            for(Schema.PicklistEntry entry : picklistValues) {
                if(entry.isActive()) {
                    types.add(entry.getValue());
                }
            }
            return types;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // @AuraEnabled
    // public static void sendReminderEmails(Id campaignId) {
    //     try {
    //         // Query campaign members who haven't received emails
    //         List<CampaignMember> membersToRemind = [
    //             SELECT Id, LeadId, Lead.Email, Lead.FirstName
    //             FROM CampaignMember 
    //             WHERE CampaignId = :campaignId 
    //             AND LeadId != null 
    //             AND Lead.Email != null 
    //             AND Lead.IsFirstEmailSent__c = false
    //             LIMIT 50
    //         ];

    //         if(membersToRemind.isEmpty()) {
    //             throw new AuraHandledException('No eligible leads found for reminder emails.');
    //         }

    //         List<Messaging.SingleEmailMessage> emailMessages = new List<Messaging.SingleEmailMessage>();
    //         Campaign camp = [SELECT Name FROM Campaign WHERE Id = :campaignId];

    //         for(CampaignMember member : membersToRemind) {
    //             Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    //             email.setTargetObjectId(member.LeadId);
    //             email.setSaveAsActivity(true);
    //             email.setSubject('Reminder: ' + camp.Name);
                
    //             String emailBody = 'Hello ' + member.Lead.FirstName + ',\n\n';
    //             emailBody += 'This is a reminder about our campaign: ' + camp.Name + '.\n';
    //             emailBody += 'We noticed you haven\'t received our initial communication.\n';
                
    //             email.setPlainTextBody(emailBody);
    //             emailMessages.add(email);
    //         }

    //         if(!emailMessages.isEmpty()) {
    //             Messaging.sendEmail(emailMessages);
                
    //             // Update lead records
    //             List<Lead> leadsToUpdate = new List<Lead>();
    //             for(CampaignMember member : membersToRemind) {
    //                 leadsToUpdate.add(new Lead(
    //                     Id = member.LeadId,
    //                     IsFirstEmailSent__c = true,
    //                     FirstEmailSentDate__c = System.now()
    //                 ));
    //             }
                
    //             if(!leadsToUpdate.isEmpty()) {
    //                 update leadsToUpdate;
    //             }
    //         }
    //     } catch (Exception e) {
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }

    @AuraEnabled
    public static Map<String, Object> getCampaignComparison(Id firstCampaignId, Id secondCampaignId) {
        try {
            Map<String, Object> comparison = new Map<String, Object>();
            
            Map<String, Object> firstCampaignMetrics = getCampaignEmailMetrics(firstCampaignId);
            Map<String, Object> secondCampaignMetrics = getCampaignEmailMetrics(secondCampaignId);
            
            comparison.put('firstCampaign', firstCampaignMetrics);
            comparison.put('secondCampaign', secondCampaignMetrics);
            
            // Calculate difference percentages
            comparison.put('firstEmailDiff', 
                (Decimal)firstCampaignMetrics.get('firstEmailPercentage') - (Decimal)secondCampaignMetrics.get('firstEmailPercentage'));
            comparison.put('firstFollowUpDiff', 
                (Decimal)firstCampaignMetrics.get('firstFollowUpPercentage') - (Decimal)secondCampaignMetrics.get('firstFollowUpPercentage'));
            comparison.put('secondFollowUpDiff', 
                (Decimal)firstCampaignMetrics.get('secondFollowUpPercentage') - (Decimal)secondCampaignMetrics.get('secondFollowUpPercentage'));
            comparison.put('thirdFollowUpDiff', 
                (Decimal)firstCampaignMetrics.get('thirdFollowUpPercentage') - (Decimal)secondCampaignMetrics.get('thirdFollowUpPercentage'));
            
            return comparison;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}