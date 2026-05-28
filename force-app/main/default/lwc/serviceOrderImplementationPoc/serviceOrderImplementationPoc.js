import { api, LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getImplementationWork from "@salesforce/apex/ServiceOrderImplementationController.getImplementationWork";
import completeLines from "@salesforce/apex/ServiceOrderImplementationController.completeLines";
import completeInstallationWithDate from "@salesforce/apex/ServiceOrderImplementationController.completeInstallationWithDate";
import completePackageWithDate from "@salesforce/apex/ServiceOrderImplementationController.completePackageWithDate";
import completeServiceOrder from "@salesforce/apex/ServiceOrderImplementationController.completeServiceOrder";

const PAGE_SIZE = 5;
const PENDING_STATUS = "Pending Implementation";
const COMPLETED_STATUS = "Completed";

export default class ServiceOrderImplementation extends LightningElement {
  _recordId;
  hasLoaded = false;
  isLoading = false;
  @track orderData = {};
  @track packagesData = [];
  selectedPackageId = "all";
  selectedStatus = "all";
  searchKey = "";
  pageNumber = 1;
  selectedLineIds = new Set();
  completionModal;
  completionDate = this.getTodayIsoDate();

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    this._recordId = value;
    if (value && !this.hasLoaded) {
      this.loadWork();
    }
  }

  connectedCallback() {
    if (this.recordId && !this.hasLoaded) {
      this.loadWork();
    }
  }

  get packageOptions() {
    return [
      { label: "All packages", value: "all" },
      ...this.packagesData.map((pkg) => ({ label: pkg.name, value: pkg.id }))
    ];
  }

  get statusOptions() {
    return [
      { label: "All statuses", value: "all" },
      { label: PENDING_STATUS, value: PENDING_STATUS },
      { label: COMPLETED_STATUS, value: COMPLETED_STATUS }
    ];
  }

  get orderSummary() {
    return {
      serviceOrderNumber: this.orderData.serviceOrderNumber || "-",
      subscriptionOrderNumber: this.orderData.subscriptionOrderNumber || "-",
      contractNumber: this.orderData.contractNumber || "-",
      quoteNumber: this.orderData.quoteNumber || "-",
      status: this.orderData.serviceOrderStatus || "-",
      contractStartDate: this.orderData.contractStartDate,
      contractEndDate: this.orderData.contractEndDate
    };
  }

  get packages() {
    return this.packagesData.map((pkg) => {
      const allLines = pkg.installations.flatMap((inst) => inst.lines);
      const completedLines = allLines.filter(
        (line) => line.status === COMPLETED_STATUS
      ).length;
      const pendingLines = allLines.length - completedLines;
      const isSelected = this.selectedPackageId === pkg.id;
      return {
        ...pkg,
        totalLines: allLines.length,
        completedLines,
        pendingLines,
        completeLabel: `Complete ${pkg.name}`,
        disableCompletePackage: pendingLines === 0 || this.isLoading,
        className: isSelected ? "package-tile selected" : "package-tile"
      };
    });
  }

  get summary() {
    const installations = this.packagesData.flatMap((pkg) => pkg.installations);
    const lines = installations.flatMap((inst) => inst.lines);
    const completedCount = lines.filter(
      (line) => line.status === COMPLETED_STATUS
    ).length;
    const pendingCount = lines.filter(
      (line) => line.status === PENDING_STATUS
    ).length;
    const completionPercent =
      lines.length === 0
        ? 0
        : Math.round((completedCount / lines.length) * 100);
    return {
      packageCount: this.packagesData.length,
      installationCount: installations.length,
      pendingCount,
      completedCount,
      completionPercent
    };
  }

  get filteredRows() {
    const search = (this.searchKey || "").trim().toLowerCase();
    const selectedPackages =
      this.selectedPackageId === "all"
        ? this.packagesData
        : this.packagesData.filter((pkg) => pkg.id === this.selectedPackageId);

    const rows = [];
    selectedPackages.forEach((pkg) => {
      pkg.installations.forEach((inst) => {
        const matchingLines = inst.lines.filter((line) => {
          const statusMatch =
            this.selectedStatus === "all" ||
            line.status === this.selectedStatus;
          const searchable =
            `${pkg.name} ${inst.name} ${inst.vessel} ${inst.imo} ${line.product} ${line.action}`.toLowerCase();
          const searchMatch = !search || searchable.includes(search);
          return statusMatch && searchMatch;
        });

        if (matchingLines.length > 0) {
          const completed = matchingLines.filter(
            (line) => line.status === COMPLETED_STATUS
          ).length;
          const statusLabel =
            completed === matchingLines.length
              ? "Completed"
              : completed === 0
              ? "Pending"
              : "Partial";

          rows.push({
            ...inst,
            packageId: pkg.id,
            packageName: pkg.name,
            statusLabel,
            statusClass: `status ${statusLabel.toLowerCase()}`,
            disableCompleteInstallation:
              matchingLines.every((line) => line.status === COMPLETED_STATUS) ||
              this.isLoading,
            lines: matchingLines.map((line) => ({
              ...line,
              selected: this.selectedLineIds.has(line.id),
              disableSelect: line.status === COMPLETED_STATUS || this.isLoading,
              completedDate: line.completedDate || "-",
              actionClass:
                line.action === "Remove Product"
                  ? "action remove"
                  : "action add",
              badgeClass:
                line.status === COMPLETED_STATUS
                  ? "badge completed"
                  : "badge pending"
            }))
          });
        }
      });
    });
    return rows;
  }

  get pagedRows() {
    const start = (this.pageNumber - 1) * PAGE_SIZE;
    return this.filteredRows.slice(start, start + PAGE_SIZE);
  }

  get hasRows() {
    return this.filteredRows.length > 0;
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.filteredRows.length / PAGE_SIZE));
  }

  get pageLabel() {
    return `Page ${this.pageNumber} of ${this.totalPages}`;
  }

  get disablePrevious() {
    return this.pageNumber <= 1 || this.isLoading;
  }

  get disableNext() {
    return this.pageNumber >= this.totalPages || this.isLoading;
  }

  get disableCompleteSelected() {
    return this.selectedLineIds.size === 0 || this.isLoading;
  }

  get disableSelectVisible() {
    return (
      this.isLoading ||
      !this.pagedRows.some((row) =>
        row.lines.some((line) => line.status === PENDING_STATUS)
      )
    );
  }

  get disableCompleteServiceOrder() {
    return (
      this.isLoading ||
      this.summary.pendingCount > 0 ||
      this.orderData.serviceImplementationCompleted === true
    );
  }

  get completeServiceOrderLabel() {
    return this.orderData.serviceImplementationCompleted === true
      ? "Service Order Completed"
      : "Complete Service Order";
  }

  get showCompletionModal() {
    return Boolean(this.completionModal);
  }

  get completionModalTitle() {
    return this.completionModal?.title || "";
  }

  get completionTargetName() {
    return this.completionModal?.targetName || "";
  }

  get completionPendingCount() {
    return this.completionModal?.pendingCount || 0;
  }

  get disableConfirmCompletion() {
    return this.isLoading || !this.completionDate || !this.isCompletionDateValid;
  }

  get isCompletionDateValid() {
    if (!this.completionDate) {
      return false;
    }
    if (
      this.orderData.contractStartDate &&
      this.completionDate < this.orderData.contractStartDate
    ) {
      return false;
    }
    if (
      this.orderData.contractEndDate &&
      this.completionDate > this.orderData.contractEndDate
    ) {
      return false;
    }
    return true;
  }

  get completionDateMessage() {
    if (!this.orderData.contractStartDate && !this.orderData.contractEndDate) {
      return "";
    }
    return `Select a date from ${this.orderData.contractStartDate || "contract start"} to ${this.orderData.contractEndDate || "contract end"}.`;
  }

  async loadWork() {
    this.isLoading = true;
    try {
      const data = await getImplementationWork({ orderId: this.recordId });
      this.applyResponse(data);
      this.hasLoaded = true;
    } catch (error) {
      this.showError(error);
    } finally {
      this.isLoading = false;
    }
  }

  applyResponse(data) {
    this.orderData = data?.orderSummary || {};
    this.packagesData = this.normalizePackages(data);
    this.selectedLineIds = new Set();
    this.closeCompletionModal();
    if (this.pageNumber > this.totalPages) {
      this.pageNumber = this.totalPages;
    }
  }

  normalizePackages(data) {
    const packageMap = new Map();
    (data?.packages || []).forEach((pkg) => {
      packageMap.set(pkg.packageId, {
        id: pkg.packageId,
        name: pkg.packageName || "Unassigned Package",
        installations: []
      });
    });

    (data?.installations || []).forEach((inst) => {
      if (!packageMap.has(inst.packageId)) {
        packageMap.set(inst.packageId, {
          id: inst.packageId,
          name: inst.packageName || "Unassigned Package",
          installations: []
        });
      }
      packageMap.get(inst.packageId).installations.push({
        id: inst.installationId,
        name: inst.installationName,
        recordUrl: `/lightning/r/Installation__c/${inst.installationId}/view`,
        vessel: inst.vesselName || "",
        imo: inst.imo || "N/A",
        lines: (inst.lines || []).map((line) => ({
          id: line.lineId,
          product: line.productName,
          action: line.action,
          status: line.status,
          completedDate: line.completedDate
        }))
      });
    });

    return Array.from(packageMap.values()).filter(
      (pkg) => pkg.installations.length > 0
    );
  }

  handlePackageChange(event) {
    this.selectedPackageId = event.detail.value;
    this.resetPagingAndSelection();
  }

  handlePackageTileClick(event) {
    this.selectedPackageId = event.currentTarget.dataset.id;
    this.resetPagingAndSelection();
  }

  handleStatusChange(event) {
    this.selectedStatus = event.detail.value;
    this.resetPagingAndSelection();
  }

  handleSearch(event) {
    this.searchKey = event.detail.value;
    this.resetPagingAndSelection();
  }

  handleLineSelect(event) {
    const lineId = event.target.dataset.lineId;
    if (event.target.checked) {
      this.selectedLineIds.add(lineId);
    } else {
      this.selectedLineIds.delete(lineId);
    }
    this.selectedLineIds = new Set(this.selectedLineIds);
  }

  handleSelectVisiblePending() {
    const selectedIds = new Set(this.selectedLineIds);
    this.pagedRows.forEach((row) => {
      row.lines
        .filter((line) => line.status === PENDING_STATUS)
        .forEach((line) => selectedIds.add(line.id));
    });
    this.selectedLineIds = selectedIds;
  }

  async handleCompleteSelected() {
    await this.runMutation(() =>
      completeLines({
        orderId: this.recordId,
        installationLineIds: Array.from(this.selectedLineIds)
      })
    );
  }

  async handleCompleteInstallation(event) {
    const installationId = event.currentTarget.dataset.installationId;
    const row = this.filteredRows.find((item) => item.id === installationId);
    const pendingCount =
      row?.lines?.filter((line) => line.status === PENDING_STATUS).length || 0;
    this.openCompletionModal({
      type: "installation",
      id: installationId,
      title: "Complete Installation",
      targetName: row?.name || "installation",
      pendingCount
    });
  }

  handleConfirmCompletePackage(event) {
    const packageId = event.currentTarget.dataset.packageId;
    const pkg = this.packages.find((item) => item.id === packageId);
    this.openCompletionModal({
      type: "package",
      id: packageId,
      title: "Complete Package",
      targetName: pkg?.name || "package",
      pendingCount: pkg?.pendingLines || 0
    });
  }

  handleCancelCompletePackage() {
    this.closeCompletionModal();
  }

  handleCompletionDateChange(event) {
    this.completionDate = event.detail.value;
  }

  async handleConfirmCompletion() {
    const modal = this.completionModal;
    if (!modal || !this.completionDate) {
      return;
    }

    if (modal.type === "installation") {
      await this.runMutation(() =>
        completeInstallationWithDate({
          orderId: this.recordId,
          installationId: modal.id,
          completionDate: this.completionDate
        })
      );
      return;
    }

    await this.runMutation(() =>
      completePackageWithDate({
        orderId: this.recordId,
        packageId: modal.id,
        completionDate: this.completionDate
      })
    );
  }

  async handleCompleteServiceOrder() {
    await this.runMutation(() =>
      completeServiceOrder({ orderId: this.recordId })
    );
  }

  handlePrevious() {
    this.pageNumber = Math.max(1, this.pageNumber - 1);
    this.selectedLineIds = new Set();
  }

  handleNext() {
    this.pageNumber = Math.min(this.totalPages, this.pageNumber + 1);
    this.selectedLineIds = new Set();
  }

  handleRefresh() {
    this.loadWork();
  }

  resetPagingAndSelection() {
    this.pageNumber = 1;
    this.selectedLineIds = new Set();
  }

  openCompletionModal(config) {
    this.completionDate = this.getTodayIsoDate();
    this.completionModal = config;
  }

  closeCompletionModal() {
    this.completionModal = undefined;
  }

  getTodayIsoDate() {
    return new Date().toISOString().slice(0, 10);
  }

  async runMutation(action) {
    this.isLoading = true;
    try {
      const data = await action();
      this.applyResponse(data);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Implementation work updated.",
          variant: "success"
        })
      );
    } catch (error) {
      this.showError(error);
    } finally {
      this.isLoading = false;
    }
  }

  showError(error) {
    const message =
      error?.body?.message ||
      error?.message ||
      "Unable to update implementation work.";
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Error",
        message,
        variant: "error"
      })
    );
  }
}
