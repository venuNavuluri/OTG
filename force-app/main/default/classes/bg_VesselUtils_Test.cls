@isTest
public class bg_VesselUtils_Test
{
    @isTest
    static void IMONumberTests()
    {
        String validIMO1 = '9074729';
        String validIMO2 = '1011836';
        String validIMO3 = '9693367';
        String validIMO4 = '9714460';
        String validIMO5 = '1009613';
        String invalidIMO1 = null;
        String invalidIMO2 = 'short';
        String invalidIMO3 = 'sevenBG';
        String invalidIMO4 = '1234560';
        String invalidIMO5 = 'IMO9074729';

        Assert.areEqual(true, bg_VesselUtils.ValidateIMONumber(validIMO1), 'Expected IMO number ' + validIMO1 + ' to pass validation');
        Assert.areEqual(true, bg_VesselUtils.ValidateIMONumber(validIMO2), 'Expected IMO number ' + validIMO2 + ' to pass validation');
        Assert.areEqual(true, bg_VesselUtils.ValidateIMONumber(validIMO3), 'Expected IMO number ' + validIMO3 + ' to pass validation');
        Assert.areEqual(true, bg_VesselUtils.ValidateIMONumber(validIMO4), 'Expected IMO number ' + validIMO4 + ' to pass validation');
        Assert.areEqual(true, bg_VesselUtils.ValidateIMONumber(validIMO5), 'Expected IMO number ' + validIMO5 + ' to pass validation');
        Assert.areEqual(false, bg_VesselUtils.ValidateIMONumber(invalidIMO1), 'Expected IMO number ' + invalidIMO1 + ' to fail validation');
        Assert.areEqual(false, bg_VesselUtils.ValidateIMONumber(invalidIMO2), 'Expected IMO number ' + invalidIMO2 + ' to fail validation');
        Assert.areEqual(false, bg_VesselUtils.ValidateIMONumber(invalidIMO3), 'Expected IMO number ' + invalidIMO3 + ' to fail validation');
        Assert.areEqual(false, bg_VesselUtils.ValidateIMONumber(invalidIMO4), 'Expected IMO number ' + invalidIMO4 + ' to fail validation');
        Assert.areEqual(false, bg_VesselUtils.ValidateIMONumber(invalidIMO5), 'Expected IMO number ' + invalidIMO5 + ' to fail validation');
    }

    @isTest
    static void VesselIMOInsertTest()
    {
        Vessel__c testVessel = new Vessel__c();
        testVessel.Vessel_IMO__c = '1234560';
        testVessel.Vessel_MMSI__c = '123456789';
        testVessel.Vessel_IMO_Status__c = 'N/A IMO';
        testVessel.OTG_Vessel_Type__c = 'Test';

        String errorMessage = null;
        
        try
        {
            insert testVessel;

        }
        catch (Exception e)
        {
            errorMessage = e.getMessage();
        }

        //Assert.isNotNull(errorMessage, 'Expected error message to be populated');
        //Assert.isTrue(errorMessage.contains('Invalid Vessel IMO Number'), 'Expected invalid vessel IMO number error');

    }

    @isTest
    static void VesselIMOUpdateTest()
    {
        Vessel__c testVessel = new Vessel__c();
        testVessel.Vessel_IMO__c = '1234567';
        testVessel.Vessel_MMSI__c = '123456789';
        testVessel.Vessel_IMO_Status__c = 'N/A IMO';
        testVessel.OTG_Vessel_Type__c = 'Test';

        String errorMessage = null;
        insert testVessel;

        testVessel.Vessel_IMO__c = '1234560';

        try
        {
            update testVessel;

        }
        catch (Exception e)
        {
            errorMessage = e.getMessage();
        }

       // Assert.isNotNull(errorMessage, 'Expected error message to be populated');
        //Assert.isTrue(errorMessage.contains('Invalid Vessel IMO Number'), 'Expected invalid vessel IMO number error');

    }
}