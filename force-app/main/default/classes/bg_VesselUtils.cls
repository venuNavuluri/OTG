public class bg_VesselUtils
{
    /* https://en.wikipedia.org/wiki/IMO_number#Structure
       Returns true if number provided is a valid IMO 
    */
   
    public static Boolean ValidateIMONumber(String imoNumber)
    {
        if (imoNumber != null && imoNumber.length() == 7 && imoNumber.isNumeric())
        {
            String checkDigit = imoNumber.right(1);
            String calcString = imoNumber.left(6);

            Integer multiplier = 7;
            Integer sum = 0;

            for (Integer i = 0; i<calcString.length(); i++)
            {
                System.debug(LoggingLevel.ERROR, calcString.charAt(i) + '*' + multiplier);
                sum += Integer.valueOf(calcString.substring(i, i+1)) * multiplier;
                multiplier--;
            }
            System.debug(LoggingLevel.ERROR, sum);

            String sumEndStr = String.valueOf(sum).right(1);

            System.debug(LoggingLevel.ERROR, sumEndStr + '==' + checkDigit);
            return sumEndStr == checkDigit;
        }

        return false;
    }

    public static void ValidateIMONumbers(List<Vessel__c> vessels)
    {
        for (Vessel__c vessel : vessels)
        {
            if (!ValidateIMONumber(vessel.Vessel_IMO__c))
            {
                vessel.addError('Vessel_IMO__c', 'Invalid Vessel IMO Number');
            }
        }
    }

    public static final String NON_MANUAL_FIELDS = 'Non_Manual_Fields';

    public static void ValidateManualVessel(List<Vessel__c> vessels)
    {
        Map<String, Schema.FieldSet> fsMap = Schema.SObjectType.Vessel__c.fieldSets.getMap();
        Schema.FieldSet nonManualFieldSet = fsMap.get(NON_MANUAL_FIELDS);
        
        for (Vessel__c vessel : vessels)
        {
            for (Schema.FieldSetMember field : nonManualFieldSet.getFields())
            {
                String fieldName = field.getSObjectField().getDescribe().getName();
                if (vessel.get(fieldName) != null)
                {
                    vessel.addError(fieldName, 'Field cannot be set on a manual vessel');
                }
            }
        }
    }
}