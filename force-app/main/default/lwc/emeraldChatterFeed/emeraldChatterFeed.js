import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFeed from '@salesforce/apex/ChatterConnectController.getFeed';
import postFeed from '@salesforce/apex/ChatterConnectController.postFeed';
import postFeedWithFiles from '@salesforce/apex/ChatterConnectController.postFeedWithFiles';
import deleteFeedElement from '@salesforce/apex/ChatterConnectController.deleteFeedElement';
import getFeedEditPermissions from '@salesforce/apex/ChatterConnectController.getFeedEditPermissions';
import { reduceErrors } from 'c/emeraldChatterUtils';

const PAGE_SIZE = 25;

export default class EmeraldChatterFeed extends LightningElement {

    @api recordId;
    @api headerLabel;
    @api headerIcon = 'standard:record';
    @api compactMode = false;

    @track elements = [];
    @track isLoading = true;
    @track isLoadingMore = false;
    @track isPosting = false;
    @track errorMessage;
    @track activeFilter = 'all';

    pageToken = null;
    hasMore = false;
    _lastRecordId;
    _loadToken = 0;

    renderedCallback() {
        if (this._lastRecordId !== this.recordId) {
            this._lastRecordId = this.recordId;
            if (this.recordId) {
                this.reset();
                this.loadFeed();
            }
        }
    }

    reset() {
        this.elements = [];
        this.pageToken = null;
        this.hasMore = false;
        this.errorMessage = undefined;
    }

    async loadFeed() {
        const token = ++this._loadToken;
        this.isLoading = true;
        try {
            const page = await getFeed({
                recordId: this.recordId,
                pageToken: null,
                pageSize: PAGE_SIZE
            });
            if (token !== this._loadToken) return;
            this.elements = (page.elements || []).map(el => this.decorate(el));
            this.pageToken = page.nextPageToken;
            this.hasMore = !!page.nextPageToken;
            this.errorMessage = undefined;
            this.enrichEditPermissions();
        } catch (err) {
            if (token !== this._loadToken) return;
            this.errorMessage = reduceErrors(err);
        } finally {
            if (token === this._loadToken) this.isLoading = false;
        }
    }

    async enrichEditPermissions() {
        const needsCheck = this.elements
            .filter(el => el.canEdit === false && el.actorId)
            .map(el => el.id);
        if (!needsCheck.length) return;
        try {
            const map = await getFeedEditPermissions({ feedElementIds: needsCheck });
            if (!map) return;
            this.elements = this.elements.map(el => {
                if (map.hasOwnProperty(el.id)) {
                    return { ...el, canEdit: map[el.id] === true };
                }
                return el;
            });
        } catch (err) { /* silent */ }
    }

    async handleLoadMore() {
        if (!this.hasMore || this.isLoadingMore) return;
        this.isLoadingMore = true;
        try {
            const page = await getFeed({
                recordId: this.recordId,
                pageToken: this.pageToken,
                pageSize: PAGE_SIZE
            });
            const more = (page.elements || []).map(el => this.decorate(el));
            this.elements = [...this.elements, ...more];
            this.pageToken = page.nextPageToken;
            this.hasMore = !!page.nextPageToken;
            this.enrichEditPermissions();
        } catch (err) {
            this.showToast('Error', reduceErrors(err), 'error');
        } finally {
            this.isLoadingMore = false;
        }
    }

    handleRefresh() {
        this.reset();
        this.loadFeed();
    }

    async handlePost(event) {
        const { text, contentDocumentId, additionalContentDocumentIds } = event.detail;

        const fileIds = [];
        if (contentDocumentId) fileIds.push(contentDocumentId);
        if (additionalContentDocumentIds && additionalContentDocumentIds.length) {
            fileIds.push(...additionalContentDocumentIds);
        }

        const hasFiles = fileIds.length > 0;
        if (!text && !hasFiles) return;

        this.isPosting = true;
        try {
            let newEl;
            let attachmentError = null;

            if (hasFiles) {
                const result = await postFeedWithFiles({
                    recordId: this.recordId,
                    text: text || '',
                    contentVersionIds: fileIds
                });
                newEl = result.element;
                attachmentError = result.attachmentError;
            } else {
                newEl = await postFeed({
                    recordId: this.recordId,
                    text,
                    feedElementType: 'FeedItem'
                });
            }

            this.elements = [this.decorate(newEl), ...this.elements];

            // Clear the composer after a successful post
            const composer = this.template.querySelector('c-emerald-chatter-composer');
            if (composer && typeof composer.reset === 'function') composer.reset();

            if (attachmentError) {
                this.showToast('Post saved with warnings', attachmentError, 'warning');
            } else {
                this.showToast('Posted', 'Your post is live.', 'success');
            }
        } catch (err) {
            this.showToast('Error', reduceErrors(err), 'error');
        } finally {
            this.isPosting = false;
        }
    }

    async handleDelete(event) {
        const { elementId } = event.detail;
        const snapshot = [...this.elements];
        this.elements = this.elements.filter(el => el.id !== elementId);
        try {
            await deleteFeedElement({ feedElementId: elementId });
            this.showToast('Deleted', 'Post removed.', 'success');
        } catch (err) {
            this.elements = snapshot;
            this.showToast('Error', reduceErrors(err), 'error');
        }
    }

    handleEdited(event) {
        const { element } = event.detail;
        if (!element) return;
        // The child's state is authoritative — it just went through a server
        // round-trip. Replace, don't merge. (SOQL-based attachment loading
        // guarantees the response matches reality.)
        this.elements = this.elements.map(el =>
            el.id === element.id ? this.decorate(element) : el
        );
    }

    handleCommentCount(event) {
        const { elementId, delta } = event.detail;
        this.elements = this.elements.map(el =>
            el.id === elementId
                ? { ...el, commentCount: Math.max(0, (el.commentCount || 0) + delta) }
                : el
        );
    }

    get filterOptions() {
        const mk = (value, label) => ({
            value, label,
            cls: `filter-pill ${this.activeFilter === value ? 'filter-pill-active' : ''}`
        });
        return [mk('all', 'All'), mk('posts', 'Posts'), mk('files', 'With files')];
    }

    handleFilterClick(event) {
        this.activeFilter = event.currentTarget.dataset.value;
    }

    get filteredElements() {
        if (this.activeFilter === 'files') {
            return this.elements.filter(el => (el.attachments || []).length > 0);
        }
        if (this.activeFilter === 'posts') {
            return this.elements.filter(el => el.feedElementType === 'FeedItem');
        }
        return this.elements;
    }

    decorate(el) {
        return {
            ...el,
            key: el.id,
            displayTime: this.formatRelative(el.createdDate),
            hasAttachments: (el.attachments || []).length > 0
        };
    }

    formatRelative(iso) {
        if (!iso) return '';
        const d = new Date(iso);
        const diff = (Date.now() - d.getTime()) / 1000;
        if (diff < 60) return 'just now';
        if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
        if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
        if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
        return d.toLocaleDateString();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get hasElements() { return this.filteredElements.length > 0; }
    get showEmpty() { return !this.isLoading && !this.errorMessage && !this.hasElements; }
    get feedClass() { return `feed ${this.compactMode ? 'feed-compact' : ''}`; }
}