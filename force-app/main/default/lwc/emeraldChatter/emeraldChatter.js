import { LightningElement, api, wire, track } from 'lwc';
import getConfigs from '@salesforce/apex/ChatterConnectController.getConfigs';
import getRecordsForConfig from '@salesforce/apex/ChatterConnectController.getRecordsForConfig';
import { reduceErrors } from 'c/emeraldChatterUtils';

export default class EmeraldChatter extends LightningElement {

    @api recordId;
    @api useRecordContext = false;
    @api compactMode = false;

    @track configs = [];
    @track configState = {};
    @track activeRecordId;
    @track activeRecordLabel;
    @track activeRecordIcon;
    @track activeConfigDeveloperName;
    @track isLoadingConfigs = true;
    @track errorMessage;
    @track railCollapsed = false;

    connectedCallback() {
        if (this.recordId) {
            this.activeRecordId = this.recordId;
            this.activeRecordLabel = 'Record';
            this.activeRecordIcon = 'standard:record';
        }
    }

    @wire(getConfigs)
    wiredConfigs({ data, error }) {
        if (data) {
            this.configs = data.map(c => ({ ...c, key: c.developerName }));
            this.isLoadingConfigs = false;
            this.errorMessage = undefined;
        } else if (error) {
            this.errorMessage = reduceErrors(error);
            this.isLoadingConfigs = false;
        }
    }

    async handleConfigClick(event) {
        const devName = event.currentTarget.dataset.dev;
        if (!devName) return;
        const current = this.configState[devName] || {};
        const willExpand = !current.expanded;

        this.configState = {
            ...this.configState,
            [devName]: { ...current, expanded: willExpand }
        };

        if (willExpand && !current.records && !current.loading) {
            await this.loadRecords(devName);
        }
    }

    async loadRecords(devName) {
        this.configState = {
            ...this.configState,
            [devName]: { ...this.configState[devName], loading: true, error: undefined }
        };
        try {
            const records = await getRecordsForConfig({ configDeveloperName: devName });
            this.configState = {
                ...this.configState,
                [devName]: {
                    ...this.configState[devName],
                    loading: false,
                    records: records || []
                }
            };
            if (!this.activeRecordId && records && records.length) {
                this.selectRecord(records[0], devName);
            }
        } catch (err) {
            this.configState = {
                ...this.configState,
                [devName]: {
                    ...this.configState[devName],
                    loading: false,
                    records: [],
                    error: reduceErrors(err)
                }
            };
        }
    }

    handleRecordClick(event) {
        const recId   = event.currentTarget.dataset.id;
        const devName = event.currentTarget.dataset.dev;
        const cfg     = this.configState[devName];
        const rec     = (cfg?.records || []).find(r => r.id === recId);
        if (rec) this.selectRecord(rec, devName);
    }

    selectRecord(record, devName) {
        this.activeRecordId            = record.id;
        this.activeRecordLabel         = record.label;
        this.activeConfigDeveloperName = devName;
        const cfg = this.configs.find(c => c.developerName === devName);
        this.activeRecordIcon = cfg?.icon || 'standard:record';
    }

    handleRailToggle() {
        this.railCollapsed = !this.railCollapsed;
    }

    get showRail() {
        return this.configs.length > 0;
    }

    get railClass() {
        return `rail ${this.railCollapsed ? 'rail-collapsed' : ''}`;
    }

    get shellClass() {
        return `shell ${this.compactMode ? 'compact' : ''} ${this.showRail ? '' : 'no-rail'}`;
    }

    get hasActiveRecord() {
        return !!this.activeRecordId;
    }

    get activeRecordHeader() {
        return {
            id:    this.activeRecordId,
            label: this.activeRecordLabel,
            icon:  this.activeRecordIcon
        };
    }

    get noRecordSelected() {
        return !this.isLoadingConfigs && !this.activeRecordId && this.configs.length > 0;
    }

    get configsForRender() {
        return this.configs.map(cfg => {
            const state = this.configState[cfg.developerName] || {};
            const records = (state.records || []).map(r => ({
                ...r,
                key: r.id,
                railItemClass: `rail-record ${r.id === this.activeRecordId ? 'rail-record-active' : ''}`
            }));
            return {
                ...cfg,
                expanded: state.expanded || false,
                loading:  state.loading || false,
                error:    state.error,
                records,
                hasRecords: records.length > 0,
                configHeaderClass: `rail-config ${state.expanded ? 'rail-config-expanded' : ''}`,
                chevronIcon: state.expanded ? 'utility:chevrondown' : 'utility:chevronright'
            };
        });
    }
}