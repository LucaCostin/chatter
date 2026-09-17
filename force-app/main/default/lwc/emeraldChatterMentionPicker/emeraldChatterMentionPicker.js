import { LightningElement, api, track } from 'lwc';
import searchMentions from '@salesforce/apex/ChatterConnectController.searchMentions';

export default class EmeraldChatterMentionPicker extends LightningElement {

    @api term = '';
    @api limit = 8;

    @track results = [];
    @track loading = false;

    _debounce;

    @api
    refresh(newTerm) {
        this.term = newTerm || '';
        clearTimeout(this._debounce);
        this._debounce = setTimeout(() => this.search(), 180);
    }

    async search() {
        if (!this.term) { this.results = []; return; }
        this.loading = true;
        try {
            const raw = await searchMentions({ term: this.term, limitSize: this.limit });
            this.results = (raw || []).map(r => ({ ...r, key: r.id }));
        } catch (e) {
            this.results = [];
        } finally {
            this.loading = false;
        }
    }

    handlePick(event) {
        const id   = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        this.dispatchEvent(new CustomEvent('mentionselect', {
            detail: { id, name }
        }));
    }

    get hasResults() {
        return this.results.length > 0;
    }
}