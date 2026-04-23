public with sharing class AutomationBypassFlowAction {

    public class Request {
        @InvocableVariable(required=true)
        public String key; // e.g. FLOW:My_Flow_API_Name
    }

    public class Response {
        @InvocableVariable
        public Boolean bypass;
    }

    @InvocableMethod(label='Automation Bypass - Should Bypass Flow')
    public static List<Response> shouldBypass(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request r : requests) {
            Response out = new Response();
            out.bypass = AutomationBypass.bypassFlows(r.key);
            results.add(out);
        }
        return results;
    }
}