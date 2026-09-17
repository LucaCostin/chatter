import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getComments from '@salesforce/apex/ChatterConnectController.getComments';
import postComment from '@salesforce/apex/ChatterConnectController.postComment';
import likeFeedElement from '@salesforce/apex/ChatterConnectController.likeFeedElement';
import unlikeFeedElement from '@salesforce/apex/ChatterConnectController.unlikeFeedElement';
import updateFeedWithFiles from '@salesforce/apex/ChatterConnectController.updateFeedWithFiles';
import getCommentEnrichment from '@salesforce/apex/ChatterConnectController.getCommentEnrichment';
import {
    reduceErrors,
    stripHtml,
    relativeTime,
    escapeHtml,
    mentionTokensToLinks,
    wireTokensToComposerTokens
} from 'c/emeraldChatterUtils';

const COMMENT_PAGE_SIZE = 10;

export default class EmeraldChatterFeedItem extends LightningElement {

    // ===== Comment thread state =====
    @track commentsOpen = false;
    @track comments = [];
    @track commentsLoading = false;
    @track commentsPageToken = null;
    @track commentsHasMore = false;

    // ===== Post edit state =====
    @track isEditing = false;
    @track editValue = '';
    @track editSaving = false;

    // ===== Post delete state =====
    @track isConfirmingDelete = false;

    // ===== Internal working copy of the element prop =====
    _element;
    _el;

    @api
    set element(value) {
        this._element = value;
        this._el = value ? {
            ...value,
            displayTime: relativeTime(value.createdDate)
        } : null;
    }
    get element() { return this._element; }
    get el() { return this._el || {}; }

    // ============================================================
    //  LIKE
    // ============================================================

    async handleLikeClick() {
        const wasLiked = this._el.currentUserLike;
        const prevLikeId = this._el.myLikeId;

        this._el = {
            ...this._el,
            currentUserLike: !wasLiked,
            likeCount: wasLiked
                ? Math.max(0, this._el.likeCount - 1)
                : this._el.likeCount + 1
        };

        try {
            if (wasLiked) {
                await unlikeFeedElement({ likeId: prevLikeId });
                this._el = { ...this._el, myLikeId: null };
            } else {
                const newLikeId = await likeFeedElement({ feedElementId: this._el.id });
                this._el = { ...this._el, myLikeId: newLikeId };
            }
        } catch (err) {
            this._el = {
                ...this._el,
                currentUserLike: wasLiked,
                likeCount: wasLiked
                    ? this._el.likeCount + 1
                    : Math.max(0, this._el.likeCount - 1),
                myLikeId: prevLikeId
            };
            this.showToast('Error', reduceErrors(err), 'error');
        }
    }

    // ============================================================
    //  POST EDIT
    // ============================================================

    handleEditClick() {
        this.isEditing = true;
        // Convert server wire format {005|Name} → anchor pill for the RTE
        this.editValue = wireTokensToComposerTokens(this._el.text || '');
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const c = this.template.querySelector('c-emerald-chatter-composer.edit-rte');
            if (c && typeof c.setValue === 'function') {
                c.setValue(this.editValue);
                if (typeof c.focus === 'function') c.focus();
            }
        }, 0);
    }

    handleEditChange(event) {
        this.editValue = event.detail.text || '';
    }

    handleEditCancel() {
        this.isEditing = false;
        this.editValue = '';
    }

    async handleEditSubmit(event) {
        const { text, contentVersionIds } = event.detail;
        const plain = stripHtml(text || '').trim();
        if (!plain && (!contentVersionIds || !contentVersionIds.length)) return;

        this.editSaving = true;

        try {
            const updated = await updateFeedWithFiles({
                feedElementId: this._el.id,
                text: text || '',
                newContentVersionIds: contentVersionIds || []
            });

            this._el = {
                ...updated,
                displayTime: relativeTime(updated.createdDate)
            };

            this.isEditing = false;
            this.editValue = '';
            this.dispatchEvent(new CustomEvent('edited', {
                detail: { element: this._el }
            }));
            this.showToast('Saved', 'Post updated.', 'success');
        } catch (err) {
            this.showToast('Error', reduceErrors(err), 'error');
        } finally {
            this.editSaving = false;
        }
    }

    // ============================================================
    //  COMMENTS
    // ============================================================

    async handleCommentToggle() {
        this.commentsOpen = !this.commentsOpen;

        if (this.commentsOpen && this.comments.length === 0) {
            this.loadCommentsFast();
        }

        if (this.commentsOpen) {
            // Autofocus the comment composer once it renders
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const c = this.template.querySelector('c-emerald-chatter-composer.comment-composer-rt');
                if (c && typeof c.focus === 'function') c.focus();
            }, 0);
        }
    }

    async loadCommentsFast() {
        this.commentsLoading = true;
        try {
            const page = await getComments({
                feedElementId: this._el.id,
                pageToken: null,
                pageSize: COMMENT_PAGE_SIZE
            });
            this.comments = (page.comments || []).map(c => this.decorateComment(c));
            this.commentsPageToken = page.nextPageToken;
            this.commentsHasMore = !!page.nextPageToken;
            this.enrichCommentsInBackground();
        } catch (err) {
            this.showToast('Error', reduceErrors(err), 'error');
        } finally {
            this.commentsLoading = false;
        }
    }

    async enrichCommentsInBackground() {
        const ids = this.comments.map(c => c.id);
        if (!ids.length) return;
        try {
            const enriched = await getCommentEnrichment({ commentIds: ids });
            if (!enriched) return;
            const byId = {};
            for (const e of enriched) byId[e.id] = e;
            this.comments = this.comments.map(c => {
                const e = byId[c.id];
                if (!e) return c;
                return {
                    ...c,
                    likeCount:       e.likeCount,
                    currentUserLike: e.currentUserLike,
                    myLikeId:        e.myLikeId,
                    canEdit:         e.canEdit
                };
            });
        } catch (err) { /* silent */ }
    }

    async handleLoadMoreComments() {
        if (!this.commentsHasMore || this.commentsLoading) return;
        this.commentsLoading = true;
        try {
            const page = await getComments({
                feedElementId: this._el.id,
                pageToken: this.commentsPageToken,
                pageSize: COMMENT_PAGE_SIZE
            });
            const more = (page.comments || []).map(c => this.decorateComment(c));
            this.comments = [...this.comments, ...more];
            this.commentsPageToken = page.nextPageToken;
            this.commentsHasMore = !!page.nextPageToken;
            this.enrichCommentsInBackground();
        } catch (err) {
            this.showToast('Error', reduceErrors(err), 'error');
        } finally {
            this.commentsLoading = false;
        }
    }

    async handleCommentSubmit(event) {
        const { text } = event.detail;
        const plain = stripHtml(text || '').trim();
        if (!plain) return;

        try {
            const created = await postComment({
                feedElementId: this._el.id,
                text: text || ''
            });

            if (created) {
                this.comments = [this.decorateComment(created), ...this.comments];
            }

            // Reset the composer
            const c = this.template.querySelector('c-emerald-chatter-composer.comment-composer-rt');
            if (c && typeof c.reset === 'function') c.reset();

            this._el = { ...this._el, commentCount: (this._el.commentCount || 0) + 1 };
            this.dispatchEvent(new CustomEvent('commentcount', {
                detail: { elementId: this._el.id, delta: 1 }
            }));
        } catch (err) {
            this.showToast('Error', reduceErrors(err), 'error');
        }
    }

    handleCommentDelete(event) {
        const cid = event.detail.commentId;
        this.comments = this.comments.filter(c => c.id !== cid);
        this._el = { ...this._el, commentCount: Math.max(0, (this._el.commentCount || 0) - 1) };
        this.dispatchEvent(new CustomEvent('commentcount', {
            detail: { elementId: this._el.id, delta: -1 }
        }));
    }

    handleCommentEdited(event) {
        const { comment } = event.detail;
        if (!comment) return;
        this.comments = this.comments.map(c =>
            c.id === comment.id ? this.decorateComment(comment) : c
        );
    }

    // ============================================================
    //  POST DELETE
    // ============================================================

    handleDeleteClick()  { this.isConfirmingDelete = true; }
    handleDeleteCancel() { this.isConfirmingDelete = false; }
    handleDeleteConfirm() {
        this.isConfirmingDelete = false;
        this.dispatchEvent(new CustomEvent('delete', {
            detail: { elementId: this._el.id }
        }));
    }

    // ============================================================
    //  ATTACHMENT DELETION (post-level)
    // ============================================================

    handleAttachmentDeleted(event) {
        const deletedId = event.detail.attachmentId;
        const remaining = (this._el.attachments || []).filter(a => a.id !== deletedId);
        this._el = {
            ...this._el,
            attachments: remaining,
            hasAttachments: remaining.length > 0
        };
        this.dispatchEvent(new CustomEvent('edited', {
            detail: { element: this._el }
        }));
    }

    handleAttachmentDeleteError(event) {
        this.showToast('Error', event.detail.message, 'error');
    }

    // ============================================================
    //  HELPERS
    // ============================================================

    decorateComment(c) {
        return {
            ...c,
            key: c.id,
            displayTime: relativeTime(c.createdDate)
        };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ============================================================
    //  GETTERS
    // ============================================================

    get elementClass() {
        return `feed-item ${this.el.currentUserLike ? 'feed-item-liked' : ''}`;
    }
    get likeButtonClass() {
        return `action-btn ${this.el.currentUserLike ? 'action-btn-active' : ''}`;
    }
    get likeLabel() {
        return this.el.likeCount > 0 ? `${this.el.likeCount}` : 'Like';
    }
    get commentLabel() {
        return this.el.commentCount > 0 ? `${this.el.commentCount}` : 'Comment';
    }
    get commentsToggleClass() {
        return `action-btn ${this.commentsOpen ? 'action-btn-active' : ''}`;
    }
    get hasComments() {
        return this.comments.length > 0;
    }
    get showEditButton() {
        return this.el.canEdit === true;
    }
    get canDeleteAttachments() {
        return this.el.canEdit === true;
    }

    get renderedTextHtml() {
        let html = mentionTokensToLinks(this.el.text || '');

        // Inline images
        const imgs = this.el.inlineImages || [];
        for (const img of imgs) {
            const token = `\\[\\[IMG:${img.position}\\]\\]`;
            const safeUrl = escapeHtml(img.url || '');
            const safeAlt = escapeHtml(img.altText || '');
            const imgTag = `<img src="${safeUrl}" alt="${safeAlt}" style="max-width:100%;border-radius:8px;margin:8px 0;display:block;" />`;
            html = html.replace(new RegExp(token, 'g'), imgTag);
        }

        html = html.replace(/\n/g, '<br/>');
        return html;
    }
}