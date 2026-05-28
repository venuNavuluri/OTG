import { LightningElement, api, wire } from "lwc";
import createOrderSuccessMsg from "@salesforce/label/c.CreateOrderSuccessMsg";
import createOrderMessage from "@salesforce/label/c.CreateOrderMessage";
import { CloseActionScreenEvent } from "lightning/actions";
import updateQuoteToOrdered from "@salesforce/apex/CreateOrderFromQuoteController.updateQuoteToOrdered";
import validateInstallationCount from "@salesforce/apex/CreateOrderFromQuoteController.validateInstallationCount";

const STEP_SERVICE_ORDER = "serviceOrder";
const STEP_CONFIRMATION = "confirmation";
const STEP_RESULT = "result";
const SERVICE_ORDER_REQUIRED = "true";
const SERVICE_ORDER_NOT_REQUIRED = "false";

export default class CreateOrderFromQuote extends LightningElement {
  createOrderMsg = true;
  message = "";
  currentStep = STEP_SERVICE_ORDER;
  hasValidationError = false;
  isCreating = false;
  serviceOrderRequirement;
  @api recordId;

  serviceOrderOptions = [
    {
      label: "Yes, Professional Services implementation is required",
      value: SERVICE_ORDER_REQUIRED
    },
    {
      label: "No, create the subscription order without Service Order control",
      value: SERVICE_ORDER_NOT_REQUIRED
    }
  ];

  @wire(validateInstallationCount, { qtId: "$recordId" })
  valMsg({ error, data }) {
    if (data) {
      if (data !== "SUCCESS") {
        this.message = data;
        this.hasValidationError = true;
        this.currentStep = STEP_RESULT;
      } else {
        this.message = createOrderMessage;
        this.hasValidationError = false;
        this.currentStep = STEP_SERVICE_ORDER;
      }
    } else if (error) {
      this.message = this.reduceError(error);
      this.hasValidationError = true;
      this.currentStep = STEP_RESULT;
    }
  }

  get showServiceOrderStep() {
    return !this.hasValidationError && this.currentStep === STEP_SERVICE_ORDER;
  }

  get showConfirmationStep() {
    return !this.hasValidationError && this.currentStep === STEP_CONFIRMATION;
  }

  get showValidationMessage() {
    return this.hasValidationError;
  }

  get showSuccessMessage() {
    return !this.hasValidationError && this.currentStep === STEP_RESULT;
  }

  get showCloseButton() {
    return this.currentStep === STEP_RESULT;
  }

  get showCancelButton() {
    return this.currentStep !== STEP_RESULT;
  }

  get showContinueButton() {
    return this.showServiceOrderStep;
  }

  get showBackButton() {
    return this.showConfirmationStep && !this.isCreating;
  }

  get showCreateButton() {
    return this.showConfirmationStep;
  }

  get isContinueDisabled() {
    return !this.serviceOrderRequirement;
  }

  get requiresServiceOrder() {
    return this.serviceOrderRequirement === SERVICE_ORDER_REQUIRED;
  }

  get requiresServiceOrderLabel() {
    return this.requiresServiceOrder ? "Yes" : "No";
  }

  get confirmationSummary() {
    return this.requiresServiceOrder
      ? "The quote will be marked as requiring Service Order implementation before the Service Order is completed."
      : "The quote will be ordered without Service Order implementation control.";
  }

  get createButtonLabel() {
    return this.isCreating ? "Creating..." : "Create Order";
  }

  goToConfirmationStep() {
    const radioGroup = this.template.querySelector(
      'lightning-radio-group[name="requiresServiceOrder"]'
    );
    if (radioGroup && !radioGroup.reportValidity()) {
      return;
    }
    this.currentStep = STEP_CONFIRMATION;
  }

  backToServiceOrderStep() {
    this.currentStep = STEP_SERVICE_ORDER;
  }

  createOrder() {
    this.isCreating = true;
    updateQuoteToOrdered({
      qtId: this.recordId,
      requiresServiceOrder: this.requiresServiceOrder
    })
      .then((result) => {
        if (result === "SUCCESS") {
          this.message = createOrderSuccessMsg;
          this.hasValidationError = false;
          this.currentStep = STEP_RESULT;
        }
      })
      .catch((error) => {
        this.message =
          this.reduceError(error) ||
          "Error occurred while creating the order. Please contact the Technical Support team.";
        this.hasValidationError = true;
        this.currentStep = STEP_RESULT;
      })
      .finally(() => {
        this.isCreating = false;
      });
  }

  handleRequiresServiceOrderChange(event) {
    this.serviceOrderRequirement = event.detail.value;
  }

  closeModal() {
    this.createOrderMsg = false;
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  reduceError(error) {
    if (!error) {
      return "";
    }
    if (Array.isArray(error.body)) {
      return error.body.map((e) => e.message).join(", ");
    }
    if (typeof error.body?.message === "string") {
      return error.body.message;
    }
    if (typeof error.message === "string") {
      return error.message;
    }
    return "An unexpected error occurred.";
  }
}
