trigger bg_Vessel_bu on Vessel__c (before update)
{
    List<Vessel__c> vesselsWithIMO = new List<Vessel__c>();
    List<Vessel__c> manualVessels = new List<Vessel__c>();

    for (Vessel__c vessel : Trigger.new)
    {
        Vessel__c oldVessel = Trigger.oldMap.get(vessel.Id);
        if (vessel.Vessel_IMO__c != null && vessel.Vessel_IMO__c != oldVessel.Vessel_IMO__c)
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