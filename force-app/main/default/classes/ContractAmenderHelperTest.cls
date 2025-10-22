@isTest
private class ContractAmenderHelperTest {
    @isTest
    static void testAmenderReturnsQuoteId() {
        Account acc = new Account(Name = 'Helper Test Account');
        insert acc;

        Contract testContract = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft'
        );
        insert testContract;

        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Status__c = 'In Review',
            SBQQ__MasterContract__c = testContract.Id
        );
        insert testQuote;

        SBQQMockHttpResponseGenerator.setQuoteId(testQuote.Id);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SBQQMockHttpResponseGenerator());
        ContractAmenderHelper helper = new ContractAmenderHelper();
        ContractAmenderHelper.QuoteModel model = helper.load(testContract.Id, true);
        System.assertNotEquals(null, model);
        System.assertNotEquals(null, model.Id);
        Test.stopTest();
    }

    @isTest
    static void testAmenderDefaultLoadOverload() {
        Account acc = new Account(Name = 'Helper Test Account 2');
        insert acc;

        Contract testContract = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft'
        );
        insert testContract;

        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Status__c = 'In Review',
            SBQQ__MasterContract__c = testContract.Id
        );
        insert testQuote;

        SBQQMockHttpResponseGenerator.setQuoteId(testQuote.Id);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SBQQMockHttpResponseGenerator());
        ContractAmenderHelper helper = new ContractAmenderHelper();
        ContractAmenderHelper.QuoteModel model = helper.load(testContract.Id);
        System.assertNotEquals(null, model);
        System.assertNotEquals(null, model.Id);
        Test.stopTest();
    }
}