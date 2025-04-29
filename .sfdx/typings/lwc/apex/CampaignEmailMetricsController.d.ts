declare module "@salesforce/apex/CampaignEmailMetricsController.getCampaignEmailMetrics" {
  export default function getCampaignEmailMetrics(param: {campaignId: any}): Promise<any>;
}
declare module "@salesforce/apex/CampaignEmailMetricsController.getAllCampaignsEmailMetrics" {
  export default function getAllCampaignsEmailMetrics(param: {startDate: any, endDate: any, userId: any}): Promise<any>;
}
declare module "@salesforce/apex/CampaignEmailMetricsController.getUserAndHisSubordinates" {
  export default function getUserAndHisSubordinates(param: {userid: any}): Promise<any>;
}
declare module "@salesforce/apex/CampaignEmailMetricsController.getCampaignTypes" {
  export default function getCampaignTypes(): Promise<any>;
}
declare module "@salesforce/apex/CampaignEmailMetricsController.getCampaignComparison" {
  export default function getCampaignComparison(param: {firstCampaignId: any, secondCampaignId: any}): Promise<any>;
}
