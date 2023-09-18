@isTest
public class bg_MergeVesselsTest
{
    @isTest
    static void MergeTest()
    {
        Vessel__c masterVessel = new Vessel__c();
        masterVessel.Name = 'Test';
        masterVessel.Vessel_IMO__c = '1234567';
        masterVessel.Vessel_MMSI__c = '123456789';
        masterVessel.Vessel_IMO_Status__c = 'Active IMO';
        masterVessel.OTG_Vessel_Type__c = 'Test';
        insert masterVessel;

        Vessel__c duplicateVessel = new Vessel__c();
        duplicateVessel.Name = 'Test';
        duplicateVessel.Vessel_IMO__c = '1234567';
        duplicateVessel.Vessel_MMSI__c = '123456789';
        duplicateVessel.Vessel_IMO_Status__c = 'N/A IMO';
        duplicateVessel.OTG_Vessel_Type__c = 'Test';

        User dataloaderUser = [SELECT Id FROM User WHERE FirstName = 'Dataloader' LIMIT 1];
        System.runAs(dataloaderUser)
        {
            insert duplicateVessel;

        }

        IHS_Company_Role__c icr = new IHS_Company_Role__c();
        icr.IMO_Company_No__c = '1234567';
        insert icr;

        Company_Relationship__c testCR = new Company_Relationship__c();
        testCR.IHS_Company_Role__c = icr.Id;
        testCR.Vessel__c = duplicateVessel.Id;
        testCR.Date_Since_Relationship__c = Date.today();
        testCR.Relationship_Type__c = 'Registered Owner';

        insert testCR;

        ContentNote testNote = new ContentNote();
        testNote.Title = 'Test Note';
        insert TestNote;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.LinkedEntityId = duplicateVessel.Id;
        cdl.ContentDocumentId = testNote.Id;
        insert cdl;
        System.debug(LoggingLevel.ERROR, [SELECT Id, LinkedEntityId FROM ContentDocumentLink WHERE Id = :cdl.Id]);


        bg_MergeVessels.MergeVesselInput input = new bg_MergeVessels.MergeVesselInput();
        input.masterVesselId = masterVessel.Id;
        input.duplicateVesselId = duplicateVessel.Id;

        bg_MergeVessels.MergeVessel(new List<bg_MergeVessels.MergeVesselInput>{input});

        List<Vessel__c> vesselResults = [SELECT Id, (SELECT Id FROM Company_Relationships__r), (SELECT Id FROM ContentDocumentLinks) FROM Vessel__c];
        
        System.debug(LoggingLevel.ERROR, [SELECT Id, LinkedEntityId FROM ContentDocumentLink WHERE Id = :cdl.Id]);
        Assert.areEqual(1, vesselResults.size());
        Assert.areEqual(1, vesselResults[0].Company_Relationships__r.size());
        Assert.areEqual(1, vesselResults[0].ContentDocumentLinks.size());


    }
}