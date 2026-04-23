import type { MaybePromise } from '../catalog/catalog.contract.js';
import type { ReceivableNote, ReceivableSettlement } from './receivable-note.js';
import type {
  IssueReceivableNoteInput,
  IssueReceivableNoteResult,
  RegisterReceivableSettlementInput,
  RegisterReceivableSettlementResult,
} from './receivable.service.js';

export interface ReceivableServiceContract {
  issueFromSale(
    input: IssueReceivableNoteInput,
  ): MaybePromise<IssueReceivableNoteResult>;
  findBySale(
    companyId: string,
    saleId: string,
  ): MaybePromise<ReceivableNote | undefined>;
  listNotes(companyId: string): MaybePromise<ReceivableNote[]>;
  listNotesByCustomer(
    companyId: string,
    customerId: string,
  ): MaybePromise<ReceivableNote[]>;
  getNote(companyId: string, noteId: string): MaybePromise<ReceivableNote>;
  listSettlements(noteId: string): MaybePromise<ReceivableSettlement[]>;
  registerSettlement(
    input: RegisterReceivableSettlementInput,
  ): MaybePromise<RegisterReceivableSettlementResult>;
}
