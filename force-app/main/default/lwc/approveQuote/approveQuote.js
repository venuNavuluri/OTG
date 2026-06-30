import { LightningElement, api } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import { RefreshEvent } from "lightning/refresh";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import previewApproval from "@salesforce/apex/ApproveQuoteController.previewApproval";
import approveQuoteAction from "@salesforce/apex/ApproveQuoteController.approveQuote";

const COMPLETE = "complete";
const ERROR = "error";
const REVIEW = "review";

export default class ApproveQuote extends LightningElement {
  _recordId;

  isLoading = true;
  isApproving = false;
  state = REVIEW;
  message = "";
  messageLines = [];
  preview;
  groups = [];
  hasLoaded = false;

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    this._recordId = value;
    if (value && !this.hasLoaded) {
      this.hasLoaded = true;
      this.loadPreview();
    }
  }

  get hasError() {
    return this.state === ERROR;
  }

  get showSuccess() {
    return this.state === COMPLETE;
  }

  get showReview() {
    return this.state === REVIEW && this.preview;
  }

  get quoteName() {
    return this.preview?.quoteName || "";
  }

  get effectiveDate() {
    return this.preview?.effectiveDate;
  }

  get blockingMessage() {
    return this.preview?.blockingMessage;
  }

  get groupCount() {
    return this.groups.length;
  }

  get quoteCurrency() {
    return this.preview?.currencyIsoCode || this.groups[0]?.currencyIsoCode || "USD";
  }

  get totalAnnualSubscriptionValue() {
    return this.preview?.totalAnnualSubscriptionValue || 0;
  }

  get showApproveButton() {
    return this.showReview && this.preview?.canApprove;
  }

  get approveButtonLabel() {
    return this.isApproving ? "Approving..." : "Approve Quote";
  }

  get closeButtonLabel() {
    return this.showSuccess ? "Done" : "Cancel";
  }

  loadPreview() {
    if (!this.recordId) {
      return;
    }
    this.isLoading = true;
    previewApproval({ quoteId: this.recordId })
      .then((result) => {
        this.preview = result;
        this.groups = (result.groups || []).map((group) => ({
          ...group,
          installationPrice: group.installationPrice || 0,
          productChangeType: group.productChangeType || "No Change",
          installationChangeType: group.installationChangeType || "No Change",
          productBadgeClass: this.badgeClass(group.productChangeType),
          installBadgeClass: this.badgeClass(group.installationChangeType)
        }));
        this.state = REVIEW;
      })
      .catch((error) => {
        this.setErrorMessage(error);
        this.state = ERROR;
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  approveQuote() {
    this.isApproving = true;
    approveQuoteAction({ quoteId: this.recordId })
      .then((result) => {
        if (result === "SUCCESS") {
          this.message = "The quote has been approved.";
          this.state = COMPLETE;
          notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
          this.dispatchEvent(new RefreshEvent());
          this.dispatchEvent(new CloseActionScreenEvent());
          window.setTimeout(() => {
            window.location.reload();
          }, 300);
        }
      })
      .catch((error) => {
        this.setErrorMessage(error);
        this.state = ERROR;
      })
      .finally(() => {
        this.isApproving = false;
      });
  }

  badgeClass(value) {
    const normalized = value || "No Change";
    return normalized === "No Change" ? "change-badge" : "change-badge change-badge_active";
  }

  closeModal() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  setErrorMessage(error) {
    const message = this.reduceError(error);
    this.message = message;
    this.messageLines = message
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line);
  }

  reduceError(error) {
    if (!error) {
      return "An unexpected error occurred.";
    }
    if (Array.isArray(error.body?.pageErrors) && error.body.pageErrors.length) {
      return error.body.pageErrors.map((e) => e.message).join("\n");
    }
    if (error.body?.fieldErrors && Object.keys(error.body.fieldErrors).length) {
      return Object.entries(error.body.fieldErrors)
        .flatMap(([fieldName, fieldErrors]) =>
          (fieldErrors || []).map((fieldError) => `${fieldError.message} Field: ${fieldName}`)
        )
        .join("\n");
    }
    if (Array.isArray(error.body?.output?.errors) && error.body.output.errors.length) {
      return error.body.output.errors.map((e) => e.message).join("\n");
    }
    if (error.body?.output?.fieldErrors && Object.keys(error.body.output.fieldErrors).length) {
      return Object.entries(error.body.output.fieldErrors)
        .flatMap(([fieldName, fieldErrors]) =>
          (fieldErrors || []).map((fieldError) => `${fieldError.message} Field: ${fieldName}`)
        )
        .join("\n");
    }
    if (Array.isArray(error.body)) {
      return error.body.map((e) => e.message).join("\n");
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
