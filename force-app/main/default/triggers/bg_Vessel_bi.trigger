trigger bg_Vessel_bi on Vessel__c (before insert)
{
    List<Vessel__c> vesselsWithIMO = new List<Vessel__c>();
    List<Vessel__c> manualVessels = new List<Vessel__c>();

    for (Vessel__c vessel : Trigger.new)
    {
        if (vessel.Vessel_IMO__c != null)
        {
            vesselsWithIMO.add(vessel);
        }

        if (vessel.Source__c == 'Manual')
        {
            manualVessels.add(vessel);
        }
    }

    if (!vesselsWithIMO.isEmpty())
    {
        bg_VesselUtils.ValidateIMONumbers(vesselsWithIMO);
    }

    if (!manualVessels.isEmpty())
    {
        bg_VesselUtils.ValidateManualVessel(manualVessels);
    }
}