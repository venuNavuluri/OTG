import { LightningElement, api } from 'lwc';
export default class ExpandableSection extends LightningElement {
    @api id;
    @api label;
    @api noOfInstallations
    @api remainingInstallations
    @api installationPrice;
    @api userPrice;
    @api currencyCode;

    toggleSection(event) {
        let buttonid = event.currentTarget.dataset.buttonid;
        let currentsection = this.template.querySelector('[data-id="' + buttonid + '"]');
        if (currentsection.className.search('slds-is-open') == -1) {
            currentsection.className = 'slds-section slds-is-open';
        } else {
            currentsection.className = 'slds-section slds-is-close';
        }
    }
}