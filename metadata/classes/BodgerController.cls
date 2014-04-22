// Modify Apex Classes - from Apex!
public with sharing class BodgerController {
    // ID of the Apex Class we'll be working on
    public String bodgeId { get; set; }
    // Output for user consumption
    public String output { get; set; }
    // Apex Classes in this org
    public List<ApexClass> apexClasses { get; set; }

    // Name of class that we're working on
    private String classname;
    // Handle to the asynchronous request
    private String containerAsyncRequestId;

    // The Tooling API endpoint
    private static String baseUrl = URL.getSalesforceBaseUrl().toExternalForm() + 
        '/services/data/v28.0/tooling/';

    // Wrapper for API object
    class ApexClassMember {
        String MetadataContainerId;
        String ContentEntityId;
        String Body;
    }
    
    public class BodgerException extends Exception {
    }
    
    public BodgerController() {
        loadApexClasses();
    }
    
    private void loadApexClasses() {
        apexClasses = [SELECT Id, Name FROM ApexClass ORDER BY Name];
    }
    
    public PageReference bodge() {
        bodgeClass(bodgeId);
        
        output = 'Bodging '+classname+'. Status: '+checkStatus();
        
        return null;
    }
    
    // Call this periodically to see what's going on
    public PageReference updateStatus() {
        String status = checkStatus();
        
        if (status == 'Completed') {
            Type t = Type.forName(classname);
            // Caveat developer - the class needs a public constructor for this to work...
            MyInterface obj = (MyInterface)t.newInstance();
            String result = obj.myMethod();
            
            output = 'Done. '+classname+'.myMethod() returned \'' + result + '\'';
        } else if (status != 'Queued') {
            output = status;
        }
        
        return null;
    }

    // Get the existing class body, add an interface, and a method implementation,
    // then save the new body
    private String bodgeClass(String id) {
        String body = getClassBody(id);

        String newBody = body.replaceFirst('\\{', ' implements MyInterface {');
        Integer closeBrace = newBody.lastIndexOf('}');
        newBody = newBody.left(closeBrace)+' public String myMethod() { return \'It worked!\';} }';
        
        containerAsyncRequestId = setClassBody(id, newBody);
        
        return containerAsyncRequestId;
    }
    
    private String getClassBody(String id) {
        ApexClass apexClass = [SELECT Name, Body FROM ApexClass WHERE Id = :id];
        
        classname = apexClass.Name;

        return apexClass.body;
    }
    
    // Jump through the hoops to save a class body
    // Returns the request id
    private String setClassBody(String id, String classBody){
        HTTPRequest req = new HTTPRequest();
        req.setHeader('Authorization', 'Bearer '+UserInfo.getSessionId());
        req.setEndpoint(baseUrl+'sobjects/MetadataContainer');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{'+
            '"Name" : "SaveClass' + DateTime.now().getTime() +'"'+
        '}');

        Http h = new Http();
        HttpResponse res = h.send(req);
        if (res.getStatusCode() != 201) {
            System.debug(res.getBody());
            throw new BodgerException(res.getStatus());
        }

        String body = res.getBody();

        Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(body);
        String metadataContainerId = (String)response.get('id');

        req = new HTTPRequest();
        req.setHeader('Authorization', 'Bearer '+UserInfo.getSessionId());
        req.setEndpoint(baseUrl+'sobjects/ApexClassMember');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        ApexClassMember apexClassMember = new ApexClassMember();
        apexClassMember.MetadataContainerId = metadataContainerId;
        apexClassMember.ContentEntityId = id;
        apexClassMember.Body = classBody;
        System.debug('SERIALIZED: '+JSON.serialize(apexClassMember));
        req.setBody(JSON.serialize(apexClassMember));

        res = h.send(req);
        if (res.getStatusCode() != 201) {
            System.debug(res.getBody());
            throw new BodgerException(res.getStatus());
        }

        req = new HTTPRequest();
        req.setHeader('Authorization', 'Bearer '+UserInfo.getSessionId());
        req.setEndpoint(baseUrl+'sobjects/ContainerAsyncRequest');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{'+
            '"MetadataContainerId" : "' + metadataContainerId +'",'+
            '"isCheckOnly" : false'+
        '}');

        h = new Http();
        res = h.send(req);
        if (res.getStatusCode() != 201) {
            System.debug(res.getBody());
            throw new BodgerException(res.getStatus());
        }
        
        body = res.getBody();

        response = (Map<String, Object>)JSON.deserializeUntyped(body);
        return (String)response.get('id');
    }
    
    // See what's happening with our request
    public String checkStatus() {
        HTTPRequest req = new HTTPRequest();
        req.setHeader('Authorization', 'Bearer '+UserInfo.getSessionId());
        req.setEndpoint(baseUrl+'sobjects/ContainerAsyncRequest/'+containerAsyncRequestId);
        req.setMethod('GET');

        Http h = new Http();
        HttpResponse res = h.send(req);
        
        if (res.getStatusCode() != 200) {
            System.debug(res.getBody());
            throw new BodgerException(res.getStatus());
        }

        String body = res.getBody();
        
        System.debug(body);

        Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(body);
        String state = (String)response.get('State');
        
        return state;
    }
}