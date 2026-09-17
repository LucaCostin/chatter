import { LightningElement, api, track } from 'lwc';
import deleteAttachment from '@salesforce/apex/ChatterConnectController.deleteAttachment';
import { reduceErrors } from 'c/emeraldChatterUtils';

export default class EmeraldChatterAttachment extends LightningElement {

    @api attachment;
    @api canDelete = false;

    @track isConfirmingDelete = false;
    @track isDeleting = false;

    handleDeleteClick(event) {
        event.preventDefault();
        event.stopPropagation();
        this.isConfirmingDelete = true;
    }

    handleDeleteCancel(event) {
        event.preventDefault();
        event.stopPropagation();
        this.isConfirmingDelete = false;
    }

    async handleDeleteConfirm(event) {
        event.preventDefault();
        event.stopPropagation();

        this.isDeleting = true;
        try {
            await deleteAttachment({ contentVersionId: this.attachment.contentVersionId });
            this.isConfirmingDelete = false;
            this.dispatchEvent(new CustomEvent('attachmentdeleted', {
                detail: { attachmentId: this.attachment.id }
            }));
        } catch (err) {
            this.isConfirmingDelete = false;
            this.dispatchEvent(new CustomEvent('attachmentdeleteerror', {
                detail: { message: reduceErrors(err) }
            }));
        } finally {
            this.isDeleting = false;
        }
    }

    get iconName() {
        const ext  = (this.attachment?.fileExtension || '').toLowerCase();
        const mime = (this.attachment?.mimeType || '').toLowerCase();
        if (mime.includes('image') || ['png','jpg','jpeg','gif','webp','svg'].includes(ext)) return 'doctype:image';
        if (mime.includes('pdf') || ext === 'pdf') return 'doctype:pdf';
        if (['xls','xlsx','csv','numbers'].includes(ext)) return 'doctype:excel';
        if (['doc','docx','pages'].includes(ext)) return 'doctype:word';
        if (['ppt','pptx','key'].includes(ext)) return 'doctype:ppt';
        if (['zip','rar','7z','tar','gz'].includes(ext)) return 'doctype:zip';
        if (mime.includes('audio') || ['mp3','wav','ogg'].includes(ext)) return 'doctype:audio';
        if (mime.includes('video') || ['mp4','mov','avi'].includes(ext)) return 'doctype:video';
        return 'doctype:attachment';
    }

    get sizeLabel() {
        const bytes = this.attachment?.fileSize;
        if (!bytes && bytes !== 0) return '';
        if (bytes < 1024) return `${bytes} B`;
        if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
        return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }

    get showDeleteButton() {
        return this.canDelete === true && !this.isConfirmingDelete;
    }
}