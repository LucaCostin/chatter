import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import likeComment from '@salesforce/apex/ChatterConnectController.likeComment';
import unlikeComment from '@salesforce/apex/ChatterConnectController.unlikeComment';
import deleteComment from '@salesforce/apex/ChatterConnectController.deleteComment';
import updateComment from '@salesforce/apex/ChatterConnectController.updateComment';
import {
    reduceErrors,
    stripHtml,
    escapeHtml,
    mentionTokensToLinks,
    wireTokensToComposerTokens
} from 'c/emeraldChatterUtils';

export default class EmeraldChatterComment extends LightningElement {

    @api comment;

    @track liked;
    @track likeCount;
    @track myLikeId;
    @track liking = false;

    @track isEditing = false;
    @track editValue = '';
    @track editSaving = false;

    @track isConfirmingDelete = false;

    _text;

    connectedCallback() {
        this.liked     = this.comment.currentUserLike;
        this.likeCount = this.comment.likeCount || 0;
        this.myLikeId  = this.comment.myLikeId;
        this._text     = this.comment.text;
    }

    // ============================================================
    //  LIKE
    // ============================================================

    async handleLike() {
        if (this.liking) return;
        this.liking = true;
        const wasLiked = this.liked;
        const prevLikeId = this.myLikeId;

        this.liked = !wasLiked;
        this.likeCount = wasLiked ? Math.max(0, this.likeCount - 1) : this.likeCount + 1;

        try {
            if (wasLiked) {
                await unlikeComment({ likeId: prevLikeId });
                this.myLikeId = null;
            } else {
                const newLikeId = await likeComment({ commentId: this.comment.id });
                this.myLikeId = newLikeId;
            }
        } catch (err) {
            this.liked = wasLiked;
            this.likeCount = wasLiked ? this.likeCount + 1 : Math.max(0, this.likeCount - 1);
            this.myLikeId = prevLikeId;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: reduceErrors(err),
                variant: 'error'
            }));
        } finally {
            this.liking = false;
        }
    }

    // ============================================================
    //  EDIT
    // ============================================================

    handleEditClick() {
        this.isEditing = true;
        // Convert server wire format → anchor pill for the RTE
        this.editValue = wireTokensToComposerTokens(this._text || '');
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const c = this.template.querySelector('c-emerald-chatter-composer.comment-edit-rte');
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
        const { text } = event.detail;
        const plain = stripHtml(text || '').trim();
        if (!plain) return;

        this.editSaving = true;
        try {
            const updated = await updateComment({
                commentId: this.comment.id,
                text: text || ''
            });
            this._text = updated.text;
            this.isEditing = false;
            this.editValue = '';
            this.dispatchEvent(new CustomEvent('commentedited', {
                detail: { comment: updated }
            }));
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: reduceErrors(err),
                variant: 'error'
            }));
        } finally {
            this.editSaving = false;
        }
    }

    // ============================================================
    //  DELETE
    // ============================================================

    handleDeleteClick()  { this.isConfirmingDelete = true; }
    handleDeleteCancel() { this.isConfirmingDelete = false; }

    async handleDeleteConfirm() {
        this.isConfirmingDelete = false;
        try {
            await deleteComment({ commentId: this.comment.id });
            this.dispatchEvent(new CustomEvent('commentdelete', {
                detail: { commentId: this.comment.id }
            }));
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: reduceErrors(err),
                variant: 'error'
            }));
        }
    }

    // ============================================================
    //  GETTERS
    // ============================================================

    get likeClass() {
        return `comment-action ${this.liked ? 'comment-action-active' : ''}`;
    }
    get likeCountLabel() {
        return this.likeCount > 0 ? `${this.likeCount}` : '';
    }
    get showEditButton() {
        return this.comment.canEdit === true;
    }

    get renderedCommentHtml() {
        let html = mentionTokensToLinks(this._text || '');

        // Inline images
        const imgs = this.comment.inlineImages || [];
        for (const img of imgs) {
            const token = `\\[\\[IMG:${img.position}\\]\\]`;
            const safeUrl = escapeHtml(img.url || '');
            const safeAlt = escapeHtml(img.altText || '');
            const imgTag = `<img src="${safeUrl}" alt="${safeAlt}" style="max-width:100%;border-radius:6px;margin:6px 0;display:block;" />`;
            html = html.replace(new RegExp(token, 'g'), imgTag);
        }

        html = html.replace(/\n/g, '<br/>');
        return html;
    }
}