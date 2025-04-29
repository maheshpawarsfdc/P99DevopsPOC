public with sharing class GmailAuthService {
    public static String getAccessToken() {
        String namedCredential = 'Gmail_API';  // Ensure this matches your Named Credential in Setup
        String tokenEndpoint = 'callout:' + namedCredential + '/oauth2/token'; // This is how Named Credentials work

        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenEndpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HTTPResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (responseMap.containsKey('access_token')) {
                String accessToken = (String) responseMap.get('access_token');
                System.debug('Access Token retrieved successfully: ' + accessToken);
                return accessToken;
            }
        }

        System.debug('Failed to retrieve Access Token! Response: ' + res.getBody());
        throw new System.CalloutException('Unable to get access token from Named Credential');
    }
}