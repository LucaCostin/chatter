import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCurrentUser from '@salesforce/apex/ChatterConnectController.getCurrentUser';
import uploadFile from '@salesforce/apex/ChatterConnectController.uploadFile';
import { reduceErrors, normalizeRichTextHtml, stripHtml } from 'c/emeraldChatterUtils';

const MAX_LENGTH = 10000;
const MAX_FILE_BYTES = 5242880;

export default class EmeraldChatterComposer extends LightningElement {

    // ===== Public API =====
    @api placeholder = 'Share an update...';
    @api submitLabel = 'Share';
    @api hideAvatar = false;
    @api showCancel = false;
    @api hideAttach = false;
    @api disabled = false;
    @api compactMode = false;

    @api
    get initialValue() { return this._initialValue; }
    set initialValue(v) {
        this._initialValue = v || '';
        this.text = this._initialValue;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const rc = this.template.querySelector('c-emerald-chatter-rich-composer');
            if (rc && typeof rc.setValue === 'function') rc.setValue(this._initialValue);
        }, 0);
    }

    // ===== Internal state =====
    @track currentUser;
    @track text = '';
    @track pendingFiles = [];   // each: { file, id, name, sizeLabel, uploading }
    @track isSubmitting = false;

    _initialValue = '';

    connectedCallback() {
        this.loadUser();
    }

    async loadUser() {
        try { this.currentUser = await getCurrentUser(); }
        catch (e) { /* non-fatal */ }
    }

    // ============================================================
    //  TEXT
    // ============================================================

    handleTextChange(event) {
        this.text = event.detail.value || '';
    }

    // ============================================================
    //  FILES — store File objects, no upload yet
    // ============================================================

    openFilePicker() {
        const input = this.template.querySelector('.hidden-file-input');
        if (input) input.click();
    }

    handleFileChosen(event) {
        const files = Array.from(event.target.files || []);
        event.target.value = '';
        if (!files.length) return;

        const next = [...this.pendingFiles];
        for (const file of files) {
            // Client-side size guard — fail fast without an Apex round-trip
            if (file.size > MAX_FILE_BYTES) {
                this.showToast('File too large',
                    `${file.name} exceeds the 5 MB limit.`, 'warning');
                continue;
            }

            next.push({
                file,                                        // the raw File object
                id: 'temp-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8),
                key: 'temp-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8),
                name: file.name,
                sizeLabel: this.formatSize(file.size),
                uploading: false
            });
        }
        this.pendingFiles = next;
    }

    handleRemoveFile(event) {
        const id = event.currentTarget.dataset.id;
        this.pendingFiles = this.pendingFiles.filter(f => f.id !== id);
    }

    formatSize(bytes) {
        if (!bytes && bytes !== 0) return '';
        if (bytes < 1024) return `${bytes} B`;
        if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
        return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }

    // ============================================================
    //  SUBMIT — upload files, then fire the event
    // ============================================================

    async handleSubmit() {
        const plain = stripHtml(this.text || '').trim();
        const hasFiles = this.pendingFiles.length > 0;

        if (!plain && !hasFiles) return;
        if (plain.length > MAX_LENGTH) {
            this.showToast('Too long', `Keep it under ${MAX_LENGTH} characters.`, 'warning');
            return;
        }
        if (this.disabled || this.isSubmitting) return;

        this.isSubmitting = true;

        // Mark all files as uploading — the UI shows a spinner per chip
        this.pendingFiles = this.pendingFiles.map(f => ({ ...f, uploading: true }));

        const contentVersionIds = [];

        try {
            for (const f of this.pendingFiles) {
                const cvId = await this.uploadOne(f.file);
                contentVersionIds.push(cvId);
            }
        } catch (err) {
            // Abort: clear the uploading flag, keep the files so the user can retry
            this.pendingFiles = this.pendingFiles.map(f => ({ ...f, uploading: false }));
            this.isSubmitting = false;
            this.showToast('Upload failed', reduceErrors(err), 'error');
            return;
        }

        const htmlForServer = normalizeRichTextHtml(this.text);

        this.dispatchEvent(new CustomEvent('submit', {
            detail: { text: htmlForServer, contentVersionIds }
        }));

        // The parent will call reset() on success. We clear isSubmitting here
        // rather than blocking the parent's workflow — the parent controls
        // the actual server round-trip.
        this.isSubmitting = false;
    }

    async uploadOne(file) {
        const base64 = await this.readAsBase64(file);
        return uploadFile({
            filename: file.name,
            base64Data: base64,
            mimeType: file.type || 'application/octet-stream'
        });
    }

    readAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = reader.result || '';
                const comma = result.indexOf(',');
                resolve(comma >= 0 ? result.substring(comma + 1) : result);
            };
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }

    // ============================================================
    //  CANCEL / KEYBOARD
    // ============================================================

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleKeydown(event) {
        if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
            event.preventDefault();
            this.handleSubmit();
        }
    }

    // ============================================================
    //  PUBLIC METHODS
    // ============================================================

    @api
    reset() {
        this.text = '';
        this._initialValue = '';
        this.pendingFiles = [];
        this.isSubmitting = false;
        const rc = this.template.querySelector('c-emerald-chatter-rich-composer');
        if (rc && typeof rc.clear === 'function') rc.clear();
    }

    @api
    focus() {
        const rc = this.template.querySelector('c-emerald-chatter-rich-composer');
        if (rc && typeof rc.focus === 'function') rc.focus();
    }

    @api
    setValue(value) {
        this.text = value || '';
        const rc = this.template.querySelector('c-emerald-chatter-rich-composer');
        if (rc && typeof rc.setValue === 'function') rc.setValue(this.text);
    }

    // ============================================================
    //  UTILITIES
    // ============================================================

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ============================================================
    //  GETTERS
    // ============================================================

    get avatarUrl()       { return this.currentUser?.SmallPhotoUrl || null; }
    get userName()        { return this.currentUser?.Name || 'You'; }
    get charCount()       { return stripHtml(this.text || '').length; }
    get charLimitLabel()  { return this.charCount > MAX_LENGTH - 500 ? `${MAX_LENGTH - this.charCount} left` : ''; }
    get showCharWarning() { return this.charCount > MAX_LENGTH - 500; }
    get overLimit()       { return this.charCount > MAX_LENGTH; }
    get hasFiles()        { return this.pendingFiles.length > 0; }

    get canSubmit() {
        const hasText = stripHtml(this.text || '').trim().length > 0;
        const hasFiles = this.pendingFiles.length > 0;
        return (hasText || hasFiles)
            && !this.disabled
            && !this.isSubmitting
            && !this.overLimit;
    }
    get submitDisabled() { return !this.canSubmit; }

    get composerClass() {
        return [
            'composer',
            this.compactMode ? 'composer-compact' : '',
            this.overLimit ? 'composer-error' : '',
            this.hideAvatar ? 'composer-no-avatar' : ''
        ].filter(Boolean).join(' ');
    }
}