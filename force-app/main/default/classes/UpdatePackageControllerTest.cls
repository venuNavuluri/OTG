@IsTest
public class UpdatePackageControllerTest {

    private class UpdateContext {
        Id quoteId;
        Id packageId;
        Id firstInstallationId;
        Id secondInstallationId;
    }

    private static UpdateContext buildContext() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        UpdateContext data = new UpdateContext();
        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        Contract contractRec = TestDataFactory_OTG.createContractBasic(
            ctx.b2bAccount.Id, 'USD', Date.today(), 12, null
        );

        Package__c pack = new Package__c(
            Contract__c = contractRec.Id,
            Quote__c = ctx.quote.Id,
            Name = 'Update Package',
            Package_Name__c = 'Update Package',
            Installation_Quantity__c = 2,
            User_Quantity__c = 2
        );
        insert pack;

        SBQQ__QuoteLineGroup__c qlg = new SBQQ__QuoteLineGroup__c(
            SBQQ__Quote__c = ctx.quote.Id,
            Package__c = pack.Id,
            Name = 'Update QLG',
            Installation_Quantity__c = 2,
            User_Quantity__c = 2
        );
        insert qlg;

        List<Vessel__c> vessels = TestDataFactory_OTG.createVessels(2);
        Vessel__c vesselOne = vessels[0];
        Vessel__c vesselTwo = vessels[1];

        Installation__c instOne = new Installation__c(
            Contract_Customer__c = ctx.b2bAccount.Id,
            Package__c = pack.Id,
            Quote__c = ctx.quote.Id,
            Quote_Line_Group__c = qlg.Id,
            Installation_Order_Status__c = 'Draft',
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = vesselOne.Id
        );
        Installation__c instTwo = new Installation__c(
            Contract_Customer__c = ctx.b2bAccount.Id,
            Package__c = null,
            Quote__c = ctx.quote.Id,
            Installation_Order_Status__c = 'Draft',
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = vesselTwo.Id
        );
        insert new List<Installation__c>{ instOne, instTwo };

        data.quoteId = ctx.quote.Id;
        data.packageId = pack.Id;
        data.firstInstallationId = instOne.Id;
        data.secondInstallationId = instTwo.Id;
        return data;
    }

    @IsTest
    static void testFetchAndSaveInstallation() {
        UpdateContext data = buildContext();

        Test.startTest();
        List<Package__c> fetchedByQuote = UpdatePackageController.fetchPackages(data.quoteId);
        List<Package__c> fetchedByPackage = UpdatePackageController.getPackageData(data.packageId);
        String result = UpdatePackageController.saveInstallation(
            data.packageId,
            data.secondInstallationId,
            data.firstInstallationId
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Save should complete successfully.');
        System.assertEquals(1, fetchedByQuote.size(), 'Expected one package for the quote.');
        System.assertEquals(1, fetchedByPackage.size(), 'Expected one package by id.');

        Map<Id, Installation__c> refreshed = new Map<Id, Installation__c>([
            SELECT Id, Package__c, Installation_Order_Status__c
            FROM Installation__c
            WHERE Id IN :new Set<Id>{ data.firstInstallationId, data.secondInstallationId }
        ]);
        System.assertEquals('Terminated', refreshed.get(data.firstInstallationId).Installation_Order_Status__c,
            'Swap installation should be terminated.');
        System.assertEquals(data.packageId, refreshed.get(data.secondInstallationId).Package__c,
            'Selected installation should be assigned to the package.');
    }
}
