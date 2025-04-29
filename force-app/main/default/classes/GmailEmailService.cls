public with sharing class GmailEmailService {
    private static String NAMED_CREDENTIAL;  // Ensure it's set up in Salesforce

    public static Map<String,String> sendEmail(String toAddress, String subject, String mailBody) {

        // Retrieve the Salesforce user signature
        String userSignature='';
        String username = '';
        User userDetail= retrieveSalesforceUser();
        if(userDetail != null){
             userSignature = userDetail.Signature != null ? userDetail.Signature : '';
             username = userDetail.Username;
        }
        NAMED_CREDENTIAL = (username == 'maheshpawarsfdc@gmail.com') ? 'Gmail_API_2':'Gmail_API';

       System.debug('Named credential ::'+NAMED_CREDENTIAL);
        // Append signature to the mail body
        String fullEmailBody = mailBody + '<br>' + userSignature;

        String endpoint = 'callout:' + NAMED_CREDENTIAL + '/gmail/v1/users/me/messages/send?sendAsEmail=' + toAddress;

        // Construct raw email body
        String emailMessage = 'To: ' + toAddress + '\r\n' +
                            'Subject: =?UTF-8?B?' + EncodingUtil.base64Encode(Blob.valueOf(subject)) + '?=\r\n' +
                            'MIME-Version: 1.0\r\n' +
                            'Content-Type: text/html; charset="UTF-8"\r\n\r\n' +
                            fullEmailBody;


        // Encode email in Base64 URL-safe format (needed by Gmail API)
        String encodedEmail = EncodingUtil.base64Encode(Blob.valueOf(emailMessage))
                             .replace('+', '-').replace('/', '_').replaceAll('=', '').replace('\'', '\'');

        String jsonBody = '{"raw": "' + encodedEmail + '"}';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200 || res.getStatusCode() == 202) {
            System.debug('Email sent successfully to ' + toAddress);
            System.debug('Body'+res.getBody());
            // Parse response to get email ID
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String emailId = (String) responseMap.get('id');
            String threadId = (String) responseMap.get('threadId');

            // Fetch Message-ID
            String messageId = getMessageIdFromGmail(emailId);
            System.debug('Fetched Message-ID: ' + messageId);

            // storing messaging details in custom object
            
            Map<String,String> emailTrackResult = new Map<String,String>();
            emailTrackResult.put('email',toAddress);
            emailTrackResult.put('threadId',threadId);
            emailTrackResult.put('msgId',messageId);
            emailTrackResult.put('status','Sent');
            emailTrackResult.put('subject',subject);

            return emailTrackResult;
            

        } else {
            System.debug('Email failed: ' + res.getBody());
            throw new System.CalloutException('Gmail API Error: ' + res.getBody());
        }
    }


    private static String getMessageIdFromGmail(String emailId) {
        // Use Named Credential without manually handling OAuth token
        String endpoint = 'callout:' + NAMED_CREDENTIAL +'/gmail/v1/users/me/messages/' + emailId + '?format=metadata';
    
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
    
        Http http = new Http();
        HttpResponse res = http.send(req);
    
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> headers = (List<Object>) ((Map<String, Object>) responseMap.get('payload')).get('headers');
    
            for (Object header : headers) {
                Map<String, Object> headerMap = (Map<String, Object>) header;
                if (headerMap.get('name') == 'Message-ID') {
                    System.debug('MesageId:'+headerMap.get('value'));
                    return (String) headerMap.get('value');
                }
            }
        }
        return null;
    }
    
    

    
    // Method to retrieve Salesforce user signature
    private static User retrieveSalesforceUser() {
        // Get the current user's signature
        User currentUser = [
            SELECT Id,Username, Email, Signature 
            FROM User 
            WHERE Id = :UserInfo.getUserId() 
            LIMIT 1
        ];
        
        // Return the user's signature, or an empty string if no signature
        return currentUser;
    }
}