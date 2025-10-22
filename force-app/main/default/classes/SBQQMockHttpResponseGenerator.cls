@isTest
global class SBQQMockHttpResponseGenerator implements HttpCalloutMock {
    private static Id queuedQuoteId;

    global static void setQuoteId(Id quoteId) {
        queuedQuoteId = quoteId;
    }

    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        String quoteIdToReturn = (queuedQuoteId == null) ? 'a19000000000000AAA' : String.valueOf(queuedQuoteId);
        res.setBody('"' + quoteIdToReturn + '"');
        res.setStatusCode(200);
        queuedQuoteId = null;
        return res;
    }
}