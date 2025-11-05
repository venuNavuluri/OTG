public with sharing class EmailComposerController {
    
    public class EmailRenderResult {
        @AuraEnabled public String subject;
        @AuraEnabled public String body;
    }

    @AuraEnabled(cacheable=true)
    public static String getSupportEmailTemplate() {
        EmailTemplate template = [
            SELECT Id 
            FROM EmailTemplate 
            WHERE DeveloperName = 'Support_Email_Template' 
            LIMIT 1
        ];
        return template.Id;
    }

    @AuraEnabled
    public static EmailRenderResult renderEmailTemplate(String templateId, String leadId) {
        EmailRenderResult result = new EmailRenderResult();
        try {
            Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(templateId, null, leadId);
            result.subject = email.getSubject();
            result.body = email.getPlainTextBody();
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to render email template: ' + ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static void sendEmailAndUpdateLead(
        String leadId,
        String templateId,
        String email,
        String fromEmail,
        String cc,
        String bcc,
        String subject,
        String body
    ) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(leadId);
            mail.setTemplateId(templateId);
            mail.setToAddresses(new List<String>{ 'Support@oceantg.com' });
            mail.setReplyTo(email);
            mail.setSenderDisplayName('Support Team');
            mail.setSubject(subject);
            mail.setPlainTextBody(body);
            mail.setSaveAsActivity(true);

            if (!String.isBlank(cc)) {
                mail.setCcAddresses(cc.split(';'));
            }
            if (!String.isBlank(bcc)) {
                mail.setBccAddresses(bcc.split(';'));
            }

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });

            // Update the lead status to 'Lost/Closed' 
            Lead updateLead = new Lead(Id = leadId, Status = 'Lost/Closed', Reason_For_Closing__c = 'Tech Support Query', Reason_for_Closing_Comments__c = 'Handover to Support Team');
            update updateLead;

        } catch (Exception ex) {
            throw new AuraHandledException('Failed to send email: ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getOrgWideEmails() {
        List<String> addresses = new List<String>();
        List<OrgWideEmailAddress> emailAddresses = [SELECT Address FROM OrgWideEmailAddress];
        for (OrgWideEmailAddress owea : emailAddresses) {
            addresses.add(owea.Address);
        }
        return addresses;
    }
}