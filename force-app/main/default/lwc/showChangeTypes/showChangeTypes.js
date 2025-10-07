import { api, LightningElement, track, wire } from 'lwc';
import getQuoteLineGroupList from '@salesforce/apex/ShowChangeTypesController.getQuoteLineGroups';
import { refreshApex } from '@salesforce/apex';

export default class ShowChangeTypes extends LightningElement {
    @api recordId;
    @track showSpinner = false;

    @track qlgList;
    @track qlgListResult;
    @track qlgNewList = [];
    @track openSections = [];

    _heightInit = false;

    constructor() {
        super();
        this.onResize = this.onResize.bind(this);
    }

    @wire(getQuoteLineGroupList, { qtId: '$recordId' })
    qtLineGrpList(result) {
        this.qlgListResult = result;
        if (result.error) {
            // eslint-disable-next-line no-console
            console.error('error --> ', JSON.stringify(result.error));
        }
        if (result.data) {
            this.qlgList = result.data;
            this.buildViewModels();
        }
    }

    renderedCallback() {
        if (!this._heightInit) {
            this._heightInit = true;
            this.setMaxHeight();
            window.addEventListener('resize', this.onResize);
        }
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.onResize);
    }

    onResize() {
        this.setMaxHeight();
    }

    setMaxHeight() {
        // clamp between 220 and 560, ~48% of viewport
        const target = Math.round(window.innerHeight * 0.48);
        const clamped = Math.max(220, Math.min(560, target));

        // set height directly on the scroll container (avoid this.template.host)
        const scroller = this.template.querySelector('.scroll');
        if (scroller) {
            scroller.style.maxHeight = `${clamped}px`;
        }
    }

    buildViewModels() {
        this.qlgNewList = [];
        this.openSections = [];

        (this.qlgList || []).forEach((qlg) => {
            const installChange =
                qlg.InstallationChangeType__c ??
                qlg.Installation_Change_Type__c ??
                'No Change';
            const productChange = qlg.Product_Change_Type__c ?? 'No Change';

            const installPrice =
                qlg.Installation_Price__c !== null &&
                qlg.Installation_Price__c !== undefined
                    ? qlg.Installation_Price__c
                    : 0;

            const hasChange =
                (installChange && installChange !== 'No Change') ||
                (productChange && productChange !== 'No Change');

            const sectionStyle = hasChange
                ? '--slds-c-accordion-summary-color-background:#e8f5e9;' +
                  '--slds-c-accordion-summary-text-color:#1b5e20;'
                : '';

            this.qlgNewList.push({
                Id: qlg.Id,
                Name: qlg.Name,
                CurrencyISOCode: qlg.CurrencyISOCode,
                Installation_Price__c: installPrice,
                Product_Change_Type__c: productChange,
                InstallationChangeType__c: installChange,
                sectionStyle
            });

            this.openSections.push(qlg.Name);
        });
    }

    onRefresh() {
        this.showSpinner = true;
        this.openSections = [];
        this.qlgList = [];

        refreshApex(this.qlgListResult)
            .then(() => {
                this.qlgList = this.qlgListResult.data;
                this.buildViewModels();
                this.setMaxHeight();
                this.showSpinner = false;
            })
            .catch((error) => {
                // eslint-disable-next-line no-console
                console.error('error --> ', JSON.stringify(error));
                this.showSpinner = false;
            });
    }
}