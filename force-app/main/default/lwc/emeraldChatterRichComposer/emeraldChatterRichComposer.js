import { LightningElement, api, track } from 'lwc';
import searchMentions from '@salesforce/apex/ChatterConnectController.searchMentions';

const POLL_INTERVAL_MS = 200;
const MENTION_DEBOUNCE_MS = 180;
const MENTION_TRIGGER = '@';
const MAX_MENTION_QUERY_LENGTH = 40;

export default class EmeraldChatterRichComposer extends LightningElement {

    @api placeholder = 'Share an update...';
    @api formats = 'bold,italic,underline,strike,bullet,number,link,clean';
    @api disabled = false;
    @api compactMode = false;
    @api name = 'composer';        // used to scope querySelector for internal RTE

    @track value = '';
    @track mentionOpen = false;
    @track mentionResults = [];
    @track mentionLoading = false;

    mentionQuery = '';
    mentionAnchorIndex = -1;
    mentionDebounce;
    _pollInterval;
    _lastEmitted = '';

    connectedCallback() {
        this._startPolling();
    }

    disconnectedCallback() {
        this._stopPolling();
    }

    // ============================================================
    //  PUBLIC API
    // ============================================================

    @api
    getValue() {
        return this.value;
    }

    @api
    setValue(newValue) {
        this.value = newValue || '';
        this._lastEmitted = this.value;
        const rte = this._rte();
        if (rte) rte.value = this.value;
    }

    @api
    focus() {
        const rte = this._rte();
        if (!rte) return;
        if (typeof rte.focus === 'function') {
            try { rte.focus(); return; } catch (e) { /* fall through */ }
        }
        try {
            const editable = rte.shadowRoot
                && rte.shadowRoot.querySelector('[contenteditable="true"]');
            if (editable && typeof editable.focus === 'function') {
                editable.focus();
            }
        } catch (e) { /* LWR shadow access blocked */ }
    }

    @api
    clear() {
        this.value = '';
        this._lastEmitted = '';
        this.closeMentions();
        const rte = this._rte();
        if (rte) rte.value = '';
    }

    // ============================================================
    //  POLLING — lightning-input-rich-text fires `change` only on
    //  blur, so we detect keystrokes by polling .value
    // ============================================================

    _startPolling() {
        this._stopPolling();
        this._pollInterval = setInterval(() => this._poll(), POLL_INTERVAL_MS);
    }

    _stopPolling() {
        if (this._pollInterval) {
            clearInterval(this._pollInterval);
            this._pollInterval = null;
        }
    }

    _rte() {
        return this.template.querySelector('lightning-input-rich-text');
    }

    _poll() {
        const rte = this._rte();
        if (!rte) return;
        const current = rte.value || '';
        if (current !== this.value) {
            this.value = current;
            this._emitChange();
            this._detectMentionTrigger(current);
        }
    }

    _emitChange() {
        if (this._lastEmitted === this.value) return;
        this._lastEmitted = this.value;
        this.dispatchEvent(new CustomEvent('change', {
            detail: { value: this.value }
        }));
    }

    // ============================================================
    //  MENTION DETECTION
    // ============================================================

    _detectMentionTrigger(rawHtml) {
        if (!rawHtml) { this.closeMentions(); return; }

        const plain = this._stripHtml(rawHtml);
        const plainIdx = plain.lastIndexOf(MENTION_TRIGGER);
        if (plainIdx < 0) { this.closeMentions(); return; }

        const after = plain.substring(plainIdx + 1);
        if (/\s/.test(after)) { this.closeMentions(); return; }
        if (after.length > MAX_MENTION_QUERY_LENGTH) { this.closeMentions(); return; }

        const searchToken = MENTION_TRIGGER + after;
        const htmlIdx = rawHtml.lastIndexOf(searchToken);
        if (htmlIdx < 0) { this.closeMentions(); return; }

        this.mentionAnchorIndex = htmlIdx;
        this.mentionQuery = after;

        clearTimeout(this.mentionDebounce);
        this.mentionDebounce = setTimeout(() => this._runSearch(), MENTION_DEBOUNCE_MS);
    }

    async _runSearch() {
        if (!this.mentionQuery) { this.closeMentions(); return; }
        this.mentionLoading = true;
        this.mentionOpen = true;
        try {
            const results = await searchMentions({
                term: this.mentionQuery,
                limitSize: 8
            });
            this.mentionResults = (results || []).map(r => ({
                ...r,
                key: r.id,
                itemClass: 'mention-item'
            }));
        } catch (e) {
            this.mentionResults = [];
        } finally {
            this.mentionLoading = false;
        }
    }

    handleMentionSelect(event) {
        const mentionId = event.currentTarget.dataset.id;
        const mentionName = event.currentTarget.dataset.name || mentionId;
        
         // Defense in depth — reject anything that isn't a valid Salesforce id
        if (!/^[a-zA-Z0-9]{15}$|^[a-zA-Z0-9]{18}$/.test(mentionId)) {
            this.closeMentions();
            return;
        }
        const current = this.value || '';
        const before = current.substring(0, this.mentionAnchorIndex);
        const after = current.substring(this.mentionAnchorIndex + 1 + this.mentionQuery.length);

        const safeName = this._escapeHtml(mentionName);
        const style = 'color:#047857;font-weight:600;text-decoration:none;background:#ecfdf5;padding:1px 6px;border-radius:6px;border:1px solid #a7f3d0;';

        // Anchor with href="/005..." — survives lightning-input-rich-text's sanitizer
        const mentionHtml = `<a href="/${mentionId}" style="${style}">@${safeName}</a>&nbsp;`;

        this.value = `${before}${mentionHtml}${after}`;

        const rte = this._rte();
        if (rte) rte.value = this.value;

        this._lastEmitted = this.value;
        this.dispatchEvent(new CustomEvent('change', { detail: { value: this.value } }));
        this.closeMentions();
    }

    _escapeHtml(str) {
        if (!str) return '';
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    @api
    closeMentions() {
        this.mentionOpen = false;
        this.mentionResults = [];
        this.mentionQuery = '';
        this.mentionAnchorIndex = -1;
    }

    // ============================================================
    //  HANDLERS
    // ============================================================

    handleRteChange(event) {
        this.value = event.target.value || '';
        this._lastEmitted = this.value;
        this.dispatchEvent(new CustomEvent('change', { detail: { value: this.value } }));
        this._detectMentionTrigger(this.value);
    }

    handleKeydown(event) {
        if (event.key === 'Escape' && this.mentionOpen) {
            this.closeMentions();
            event.stopPropagation();
        }
    }

    // ============================================================
    //  HELPERS
    // ============================================================

    _stripHtml(html) {
        const tmp = document.createElement('div');
        tmp.innerHTML = html;
        return tmp.textContent || tmp.innerText || '';
    }

    get composerClass() {
        return `rich-composer ${this.compactMode ? 'rich-composer-compact' : ''}`;
    }
}