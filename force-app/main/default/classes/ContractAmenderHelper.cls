public with sharing class ContractAmenderHelper {
    public class CPQAmendmentException extends Exception {}

    public class QuoteModel {
        public Id Id;
    }

    public QuoteModel load(Id contractId) {
        return load(contractId, true);
    }

    public QuoteModel load(Id contractId, Boolean returnOnlyQuoteId) {
        AmendmentContext context = new AmendmentContext();
        context.returnOnlyQuoteId = returnOnlyQuoteId;
        String contextJson = JSON.serialize(context);

        String quoteJSON = SBQQ.ServiceRouter.load('SBQQ.ContractManipulationAPI.ContractAmender', contractId, contextJson);
        if (String.isBlank(quoteJSON)) {
            throw new CPQAmendmentException('CPQ service returned empty response.');
        }

        return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
    }

    private class AmendmentContext {
        public Boolean returnOnlyQuoteId;
    }
}