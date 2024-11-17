@isTest
global class SBQQMockHttpResponseGenerator implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"quoteJSON":"test_quote_json"}');
        res.setStatusCode(200);
        return res;
    }
}