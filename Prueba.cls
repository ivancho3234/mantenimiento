public class ald_SMSSendPostCls {
    
    /**
     * Method for consume Aldeamo's service
     * 
     */
    @future(callout=true)
    public static void sendSMS (String jsonString, String credentials,  String config ){
        
        try {
            
            //deserialize the JSON to the Account List            
            List<SObject> lstSObj = (List<SObject>)Json.deserialize(jsonString,List<SObject>.class);
            
            // get credentials
            String query = 'SELECT EndPoint__c, Password__c, User__c FROM ald_Credential__mdt WHERE DeveloperName = \'' + credentials + '\' ';
            SObject creden = queryMetadata(query);
            
            
            // encode in base64
            String authString = String.valueOf(creden.get('User__c')) + ':' + String.valueOf(creden.get('Password__c'));
            Blob beforeblob = Blob.valueOf(authString);
            string authorization = EncodingUtil.base64Encode(beforeblob);
            
            String body = createJSON (lstSObj, config);
            
            //Start http
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(String.valueOf(creden.get('EndPoint__c')));
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json;charset=UTF-8');
            request.setHeader('Authorization', 'Basic '+authorization); //
            request.setBody(body);
            HttpResponse response = http.send(request);
            system.debug(response.getBody());
            message("Hello Word")
        } catch (Exception e) {
            
            System.debug(e.getMessage());
            System.debug(e.getStackTraceString());
            
        }
    }
    
    /**
     * Method for create a JSON
     * 
     */
    public static String createJSON (list<SObject> lstSObj, String config){
        
        try{
            
            //get config metadata type
            String query = 'SELECT Object__c, Field__c, Country__c, Encoding__c,  Message__c, Message_Field__c, DateToSend__c, URL__c, URL_Field__c FROM ald_ConfSerCls__mdt WHERE DeveloperName = \'' + config + '\' ';
            SObject conSerClas = queryMetadata(query);
            
            
            String dateToSend;
            if(conSerClas.get('DateToSend__c') != null){
                Datetime dateAux = datetime.valueOf(conSerClas.get('DateToSend__c')) ;
				dateToSend =  String.valueOf(dateAux.format('YYYY-MM-dd HH:mm:ss'));
            }else{
                dateToSend = '';
            }
            
            // start JSON
            JSONGenerator gen = JSON.createGenerator(true);            
            gen.writeStartObject();
            gen.writeStringField('country', String.valueOf(conSerClas.get('Country__c')));
            if(conSerClas.get('DateToSend__c') != null){
                gen.writeStringField('dateToSend', dateToSend);
            }
            if(!String.isEmpty(String.valueOf(conSerClas.get('Encoding__c')))){
                gen.writeStringField('encoding', String.valueOf(conSerClas.get('Encoding__c')));
            }
            gen.writeStringField('message', String.valueOf(conSerClas.get('Message__c')));
            gen.writeNumberField('messageFormat', 0);
            
            //start array
            gen.writeFieldName('addresseeList');
            gen.writeStartArray();
            
            //start objects: mobile, correlationLabel, url
            String message, url;
            for(SObject ob : lstSObj){
                gen.writeStartObject();        
                gen.writeStringField('mobile', String.valueOf(ob.get(String.valueOf(conSerClas.get('Field__c')))));
                gen.writeStringField('correlationLabel', String.valueOf(ob.Id));
                try{
                    message = String.valueOf(ob.get(String.valueOf(conSerClas.get('Message_Field__c')))) != null ? String.valueOf(ob.get(String.valueOf(conSerClas.get('Message_Field__c')))) : null ;
                    if(!String.isEmpty(message))
                        gen.writeStringField('message', message   );
                }catch(Exception e){}
                try{
                    url = String.valueOf(ob.get(String.valueOf(conSerClas.get('URL_Field__c')))) != null ? String.valueOf(ob.get(String.valueOf(conSerClas.get('URL_Field__c')))) : String.valueOf(conSerClas.get('URL__c'));
                    if(!String.isEmpty(url))
                        gen.writeStringField('url', url);
                }catch(Exception e){
                    gen.writeStringField('url', String.valueOf(conSerClas.get('URL__c')));
                }                
                gen.writeEndObject();
            }
            gen.writeEndArray();
            
            //End array
            gen.writeEndObject();
            gen.close();
            //End JSON

            String body = gen.getAsString();
            system.debug(body);
            return body;
            
        } catch(Exception e) {
            
            System.debug(e.getMessage());
            return null;
            
        }
    }
    
    /**
     * Method for get metadata
     * 
     */
    public static SObject queryMetadata(String query){
        
        list<SObject> lstMetaData = ald_CustomMetadataDAO.getCustomMetadataRecords(query);
        return lstMetaData[0];
        
    }
    
    /**
     * Method for use from a process builder
     * 
     */
    @InvocableMethod(label='Send SMS' description='Send SMS to records')
    public static void sendSMS(List<Id> lstIds) {
        try {
            
            //Modify with the metadata record name
            string ald_Credential = 'SMSSendPost';
            string ald_ConfSerCls = 'config1';
            
            //get SObject type
            Schema.SObjectType sobjectType = lstIds[0].getSObjectType();
            String sobjectName = sobjectType.getDescribe().getName();
            
            //get metadata
            String queryMeta = 'SELECT Object__c, Field__c, Country__c, Encoding__c,  Message__c, Message_Field__c, DateToSend__c, URL__c, URL_Field__c FROM ald_ConfSerCls__mdt WHERE DeveloperName = \'' + ald_ConfSerCls + '\' ';
            SObject conSerClas = queryMetadata(queryMeta);
            
            //get records
            String queryRecords = 'Select Id, ' + String.valueOf(conSerClas.get('Field__c'));
            if(conSerClas.get('Message_Field__c') != null){
                queryRecords += ', ' + String.valueOf(conSerClas.get('Message_Field__c'));
            }
            if(conSerClas.get('URL_Field__c') != null){
                queryRecords += ', ' + String.valueOf(conSerClas.get('URL_Field__c'));
            }            
            queryRecords += ' From ' + sobjectName + ' Where Id in :lstIds';
            list<SObject> lstRecords = Database.query(queryRecords);
            
            //consume service
            String jsonString = json.serialize(lstRecords);        
            sendSMS(jsonString, ald_Credential, ald_ConfSerCls);
            
        } catch(Exception e) {
            
            System.debug(e.getMessage());
            
        }
    }    
}