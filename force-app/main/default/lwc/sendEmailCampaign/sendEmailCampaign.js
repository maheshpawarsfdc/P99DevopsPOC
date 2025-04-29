import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEmailTemplates from '@salesforce/apex/GmailCampaignService.getEmailTemplates';
import getTemplateDetails from '@salesforce/apex/GmailCampaignService.getTemplateDetails';
import getCampaignMembers from '@salesforce/apex/GmailCampaignService.getCampaignMembers';
import getCampaignMemberCount from '@salesforce/apex/GmailCampaignService.getCampaignMemberCount';
import retrieveSalesforceUser from '@salesforce/apex/GmailCampaignService.retrieveSalesforceUser';
//import validateEmailContent from '@salesforce/apex/GmailCampaignService.validateEmailContent';
import sendCampaignEmails from '@salesforce/apex/GmailCampaignService.sendCampaignEmails';
import sendCustomFollowUpEmails from '@salesforce/apex/FollowUpEmailService.sendCustomFollowUpEmails';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import ACTIVE_FIELD from "@salesforce/schema/Campaign.IsActive";
import NUMBER_OF_FOLLOWUPS_FIELD from "@salesforce/schema/Campaign.Number_of_Follow_Ups__c";
import { refreshApex } from "@salesforce/apex";


const FIELDS = [ACTIVE_FIELD,NUMBER_OF_FOLLOWUPS_FIELD];

export default class SendEmailCampaign extends LightningElement {
    @api recordId; // Campaign ID from record page
    
    @track subject = '';
    @track body;
    @track selectedTemplate;
    @track emailTemplates = [];
    @track recipients = [];
    @track selectedLeadIds = [];
    @track sentEmails = [];
    @track previewSubject = '';
    @track previewBody = '';
    @track invalidFields = [];
    @track recipientCount = 0;
    @track availableFields = [];
    @track commonFields = ['Name','FirstName','LastName', 'Title', 'Company', 'City']; 
    @track searchTerm = '';
    @track filteredFields = [];
    @track showFieldSelector = false;

    @track subjectFocused = false;
    @track bodyFocused = false;

    @track campaignOptions = ['Campaign Email','1st-Follow Up','2nd-Follow Up','3rd-Follow Up'];

    @track selectedCampaignOption = 'Campaign Email';
    @track isSubjectHidden = false;
    
    showPreview = false;
    showConfirmation = false;
    //showValidationResults = false;
    isContentValid = true;
    isLoading = false;
    recipientsExpanded = true;
    showRecipients = false;
    @track userSignature;
    @track isCampaignActive = false;

    connectedCallback(){
        this.getUserSignature();
    }

    // @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
    //  campaignFieldData({data,error}){
    //     if(data){
    //         this.isCampaignActive = getFieldValue(data, ACTIVE_FIELD);
    //         console.log('Is Campaign Active::',this.isCampaignActive);  
    //     }else if(error){
    //         console.log(error);
            
    //     }
    //  }

    // In SendEmailCampaign.js
    // Replace the hardcoded campaignOptions with a dynamic property
    @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
    campaignRecord({data, error}) {
        if(data) {
            this.isCampaignActive = getFieldValue(data, ACTIVE_FIELD);
            const followUpCount = getFieldValue(data, NUMBER_OF_FOLLOWUPS_FIELD) || 3; // Default to 3 if not set
            
            // Generate campaign options dynamically
            this.campaignOptions = ['Campaign Email'];
            for (let i = 1; i <= followUpCount; i++) {
                this.campaignOptions.push(`${i}${this.getOrdinalSuffix(i)}-Follow Up`);
            }
            
            // Update the campaign type options
            this.campaignTypeOpttions = this.campaignOptions.map(template => ({
                label: template,
                value: template
            }));
        } else if(error) {
            console.log(error);
        }
    }

    // Helper method to get the ordinal suffix
    getOrdinalSuffix(i) {
        const j = i % 10,
            k = i % 100;
        if (j == 1 && k != 11) {
            return "st";
        }
        if (j == 2 && k != 12) {
            return "nd";
        }
        if (j == 3 && k != 13) {
            return "rd";
        }
        return "th";
    }

    getUserSignature(){
        retrieveSalesforceUser()
        .then(result => {
            this.userSignature = result.Signature;
            console.log('sign:::',this.userSignature);
            
        })
        .catch(error => {
            console.log('error:',error);
            
        })
    }


    @track campaignTypeOpttions = this.campaignOptions.map(template => ({
        label: template,
        value: template
    }));

    campaignTypeHandler(event){
        this.selectedCampaignOption = event.target.value;
        console.log('selecte campaign::',this.selectedCampaignOption);
        this.isSubjectHidden = this.selectedCampaignOption !== 'Campaign Email';
        //refreshApex(this.recipients);
        this.loadCampaignMembers();
        this.resetValues();
    }

    resetValues(){
        this.body = '';
        this.subject = '';
        this.selectedTemplate = '';
    }
    
    // Column definitions for recipient datatable
    recipientColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'Email', fieldName: 'Email', type: 'email' },
        { label: 'Company', fieldName: 'Company', type: 'text' }
    ];
    
    // Column definitions for email status datatable
    statusColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'Email', fieldName: 'Email', type: 'email' },
        { label: 'Status', fieldName: 'Status', type: 'text' }
    ];
    
    // Wire method to fetch email templates
    @wire(getEmailTemplates, {campaigntype :'$selectedCampaignOption'})
    wiredTemplates({ error, data }) {
        if (data) {
            this.emailTemplates = data.map(template => ({
                label: template.Name,
                value: template.Id
            }));
            
            // Add empty option
            this.emailTemplates.unshift({ label: '--Select a Template--', value: '' });
        } else if (error) {
            this.showToast('Error', 'Failed to load email templates: ' + this.reduceErrors(error), 'error');
        }
    }
    
    // Wire method to fetch campaign member count
    @wire(getCampaignMemberCount, { campaignId: '$recordId' ,followUpType : '$selectedCampaignOption'})
    wiredMemberCount({ error, data }) {
        if (data !== undefined) {
            this.recipientCount = data;
            console.log('recipientCount::',this.recipientCount);
            if (data > 0) {
                this.loadCampaignMembers();
            }
        } else if (error) {
            this.showToast('Error', 'Failed to load recipient count: ' + this.reduceErrors(error), 'error');
        }
    }
    
    // Load campaign members
    loadCampaignMembers() {
        if (this.recordId) {
            this.isLoading = true;
            getCampaignMembers({ campaignId: this.recordId , followUpType : this.selectedCampaignOption, isActive : this.isCampaignActive})
                .then(result => {
                    this.recipients = result;
                    console.log('lengthhh::',this.recipients.length);
                    
                    if (this.recipients.length > 0) {
                        this.showRecipients = true;
                        
                        // Pre-select all rows
                        this.preSelectedRows = this.recipients.map(row => row.Id);
                        this.selectedLeadIds = [...this.preSelectedRows];
                    }
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to load recipients: ' + this.reduceErrors(error), 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }
    

    // Handle template selection change
    handleTemplateChange(event) {
        this.selectedTemplate = event.target.value;
        const templateId = event.detail.value;
        if (templateId) {
            this.isLoading = true;
            getTemplateDetails({ templateId })
                .then(result => {
                    // Clean up the body by removing any extra symbols like ]]>
                    let cleanedBody = result.body || '';
                    // cleanedBody = cleanedBody.replaceAll('<p>', '')
                    // .replaceAll('</p>', '<br>');
                    console.log('cleanedBody', cleanedBody);
                    

                    // Set subject and body, ensuring they are editable
                    this.subject = result.subject || '';
                    this.body = cleanedBody;

                    // Explicitly set the value of rich text editor
                    const richTextEditor = this.template.querySelector('lightning-input-rich-text');
                    if (richTextEditor) {
                        richTextEditor.value = cleanedBody;
                    }
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to load template details: ' + this.reduceErrors(error), 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } else {
            // Clear fields when no template is selected
            this.subject = '';
            this.body = '';
            
            // Clear rich text editor
            const richTextEditor = this.template.querySelector('lightning-input-rich-text');
            if (richTextEditor) {
                richTextEditor.value = '';
            }
        }
    }
    
    // Handle row selection in datatable
    handleRowSelection(event) {
        this.selectedLeadIds = event.detail.selectedRows.map(row => row.Id);
    }
    
    // Toggle recipients section expanded/collapsed
    toggleRecipients() {
        this.recipientsExpanded = !this.recipientsExpanded;
    }
    
    // Handle subject input change
    handleSubjectChange(event) {
        
        
        this.subject = event.target.value;
    }
    
    // Handle body input change
    handleBodyChange(event) {
        if (event && event.detail && event.detail.value !== undefined) {
            // Directly update the body with the new value
            this.body = event.detail.value;
        }
    }
    



    handleFocus(event) {
        // Store the last focused field (either subject or body)
        console.log('subject data id: ',event.target.dataset.id);
        const focusedElement = event.target.dataset.id;

        if(focusedElement == 'subjectInput'){
            this.subjectFocused = true;
            this.bodyFocused = false;
        }else if(focusedElement == 'bodyInput'){
            this.bodyFocused = true;
            this.subjectFocused = false;
        }
    }

    insertMergeField(event) {
        const field = event.target.dataset.field;
        const mergeField = `{!Lead.${field}}`;
        
        // Same insertion logic as insertMergeField
        const subjectInput = this.template.querySelector('lightning-input[data-id="subjectInput"]');

        console.log('subjectinput',subjectInput );
        
        const richTextEditor = this.template.querySelector('lightning-input-rich-text');
        console.log('richTextEditor',richTextEditor );
        
        if (subjectInput &&  this.subjectFocused) {

            console.log('cursorEntered', subjectInput.matches(':focus'));
            console.log('cursorPosition', subjectInput.selectionStart);

            const cursorPosition = subjectInput.selectionStart;
            
            const currentSubject = this.subject || '';
            this.subject = 
                currentSubject.slice(0, cursorPosition) + 
                mergeField + 
                currentSubject.slice(cursorPosition);
           
        } else if (richTextEditor && this.bodyFocused) {


            console.log('entered rich text area');
            try {
                // Get current selection
                const selection = window.getSelection();
                if (selection.rangeCount > 0) {
                    const range = selection.getRangeAt(0);
                    // Create a text node with the merge field
                    const mergeFieldNode = document.createTextNode(mergeField);
                    // Insert the merge field at the current cursor position
                    range.deleteContents();
                    range.insertNode(mergeFieldNode);
                    // Move cursor after the inserted merge field
                    range.setStartAfter(mergeFieldNode);
                    range.collapse(true);
                    selection.removeAllRanges();
                    selection.addRange(range);
                    // Update the body content
                    this.body = richTextEditor.value;
                } else {
                    // Fallback: append to the end
                    this.body = (this.body || '') + mergeField;
                }
            } catch (error) {
                console.error('Error inserting merge field:', error);
                this.body = (this.body || '') + mergeField;
            }
            
               
        } 
        
        // Close field selector
        this.showFieldSelector = false;
    }

    // Toggle field selector
    toggleFieldSelector() {
        this.showFieldSelector = !this.showFieldSelector;
    }

   
    // Preview email with sample data
    previewEmail() {
        if (!this.subject && !this.body) {
            this.showToast('Error', 'Please enter email subject and body', 'error');
            return;
        }
        
        // If no selected rows, use the first recipient or sample data
        let previewData;
        if (this.selectedLeadIds.length > 0) {
            // Find the first selected lead
            const selectedLeadId = this.selectedLeadIds[0];
            previewData = this.recipients.find(rec => rec.Id === selectedLeadId);
        } else if (this.recipients.length > 0) {
            previewData = this.recipients[0];
        } else {
            // Sample data as fallback
            previewData = {
                FirstName:'Sample',
                LastName:'Name',
                Name: 'Sample Name',
                Email: 'sample@example.com',
                Company: 'Sample Company',
                Title: 'Sales Manager',
                City: 'Hyderabad'
            };
        }
        
        // Process all possible merge fields from the selected lead
        this.previewSubject = this.processMergeFields(this.subject, previewData);
        this.previewBody = this.processMergeFields(this.body, previewData);
        
        this.showPreview = true;
    }

    // Helper method to process all merge fields
    processMergeFields(text, data) {
        if (!text) return '';
        
        // Create a mapping of merge fields to their values
        const mergeFieldMap = {
            'FirstName': data.FirstName || '',
            'LastName': data.LastName || '',
            'Name': data.Name || '',
            'Title': data.Title || '',
            'Company': data.Company || '',
            'City': data.City || ''
        };
        
        // Replace all merge fields, ensuring they are replaced even if empty
        let processed = text;
        Object.keys(mergeFieldMap).forEach(field => {
            const regex = new RegExp(`\\{!Lead\\.${field}\\}`, 'g');
            processed = processed.replace(regex, mergeFieldMap[field]);
        });
        
        return processed;
    }
    
    // Open send confirmation dialog
    confirmSendEmails() {
        if (!this.selectedLeadIds.length) {
            this.showToast('Error', 'Please select at least one recipient', 'error');
            return;
        }
        
        if (!this.subject || !this.body) {
            this.showToast('Error', 'Please enter email subject and body', 'error');
            return;
        }
        
        this.showConfirmation = true;
    }
    
    // Send emails to selected recipients
    sendEmails() {
        this.isLoading = true;
        this.closeConfirmation();

        console.log('details', this.recordId,this.selectedLeadIds, this.subject,this.body);
        
        const formattedBody = this.body.replaceAll('<p>', '<div style="line-height:1.3em;margin:0;">')
        .replaceAll('</p>', '</div>');

        sendCampaignEmails({
            campaignId: this.recordId,
            selectedLeadIds: this.selectedLeadIds,
            subject: this.subject,
            body: formattedBody
        })
            .then(result => {
                this.sentEmails = result;
                this.showToast('Success', `Email sent to ${result.length} recipients`, 'success');
                
                // Refresh member list to update who's left
                this.loadCampaignMembers();
                this.resetValues();
                this.selectedCampaignOption = 'Campaign Email';
                
            })
            .catch(error => {
                this.showToast('Error', 'Failed to send emails: ' + this.reduceErrors(error), 'error');
                this.resetValues();
                
            })
            .finally(() => {
                this.isLoading = false;
            });
    }



    sendFollowUpEmails(){
        this.isLoading = true;
        
        console.log(this.userSignature);
        
        let formattedBody = this.body.replaceAll('<p>', '<div style="line-height:1.3em;margin:0;">')
                               .replaceAll('</p>', '</div>');
    
        // Then append the signature if it exists
        if (this.userSignature) {
            // Add a div wrapper for the body content and signature
            formattedBody = '<div style="margin-bottom: 10px;">' + formattedBody + '</div>' +
                            '<div style="padding-top: 2px;>' + this.userSignature + '</div>';
        }
        sendCustomFollowUpEmails({
            campaignId: this.recordId,
            followUpType: this.selectedCampaignOption,
            customBody: formattedBody,
            selectedLeadIds: this.selectedLeadIds}) 
            .then(result => {
                this.sentEmails = result;
                this.showToast('Success', `Email sent to ${result.length} recipients`, 'success');
                
                // Refresh member list to update who's left
                this.loadCampaignMembers();
                this.resetValues();
                this.selectedCampaignOption = 'Campaign Email';
            })
            .catch(error => {
                this.showToast('Error', 'Failed to send emails: ' + this.reduceErrors(error), 'error');
                this.resetValues();
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // Close preview modal
    closePreview() {
        this.showPreview = false;
    }
    
    // Close confirmation modal
    closeConfirmation() {
        this.showConfirmation = false;
    }
    
   
    
    // Helper to show toast notifications
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
    
    // Helper to format error messages
    reduceErrors(error) {
        if (typeof error === 'string') {
            return error;
        }
        
        // UI API read errors
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        
        // UI API DML, Apex and network errors
        else if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        
        // JS errors
        else if (typeof error.message === 'string') {
            return error.message;
        }
        
        // Unknown error shape
        return 'Unknown error';
    }
    
    // Computed properties
    get recipientCountLabel() {
        return `Total Recipients: ${this.recipientCount}`;
    }
    
    get selectedCount() {
        return this.selectedLeadIds.length;
    }
    
    get toggleRecipientsLabel() {
        return this.recipientsExpanded ? 'Hide Recipients' : 'Show Recipients';
    }
    
    get isSendDisabled() {
        return  (this.selectedLeadIds.length === 0  || this.selectedCampaignOption != 'Campaign Email');
    }

    get isFollowUpDisabled(){
        return  (this.selectedLeadIds.length === 0  || this.selectedCampaignOption == 'Campaign Email');
    }
    
    get isPreviewDisabled() {
        return !this.subject && !this.body;
    }
    
    get isBatchProcess() {
        return this.selectedLeadIds.length > 90;
    }
    
    get preSelectedRows() {
        return this.selectedLeadIds;
    }
    
    set preSelectedRows(value) {
        this.selectedLeadIds = [...value];
    }
    
    get selectedRecipientsLabel() {
        return `${this.selectedCount} recipient${this.selectedCount !== 1 ? 's' : ''}`;
    }
}