declare module "@salesforce/apex/GmailCampaignService.getEmailTemplates" {
  export default function getEmailTemplates(param: {campaigntype: any}): Promise<any>;
}
declare module "@salesforce/apex/GmailCampaignService.getTemplateDetails" {
  export default function getTemplateDetails(param: {templateId: any}): Promise<any>;
}
declare module "@salesforce/apex/GmailCampaignService.getCampaignMembers" {
  export default function getCampaignMembers(param: {campaignId: any, followUpType: any, isActive: any}): Promise<any>;
}
declare module "@salesforce/apex/GmailCampaignService.getCampaignMemberCount" {
  export default function getCampaignMemberCount(param: {campaignId: any, followUpType: any}): Promise<any>;
}
declare module "@salesforce/apex/GmailCampaignService.sendCampaignEmails" {
  export default function sendCampaignEmails(param: {campaignId: any, selectedLeadIds: any, subject: any, body: any}): Promise<any>;
}
declare module "@salesforce/apex/GmailCampaignService.retrieveSalesforceUser" {
  export default function retrieveSalesforceUser(): Promise<any>;
}
