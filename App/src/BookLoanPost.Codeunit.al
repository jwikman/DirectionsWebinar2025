namespace Demo.Library;

using Microsoft.Foundation.NoSeries;

codeunit 70350 "LIB Book Loan-Post"
{
    TableNo = "LIB Book Loan Header";
    Access = Public;

    trigger OnRun()
    begin
        BookLoanHeader.Copy(Rec);
        Code();
        Rec := BookLoanHeader;
    end;

    var
        BookLoanHeader: Record "LIB Book Loan Header";
        BookLoanLine: Record "LIB Book Loan Line";
        PostedBookLoanHeader: Record "LIB Posted Book Loan Header";
        PostedBookLoanLine: Record "LIB Posted Book Loan Line";
        BookLoanLedgerEntry: Record "LIB Book Loan Ledger Entry";
        LibrarySetup: Record "LIB Library Setup";
        NoSeries: Codeunit "No. Series";
        PostedDocNo: Code[20];
        NoMemberErr: Label 'Member No. must have a value in Book Loan Header: No.=%1. It cannot be zero or empty.', Comment = '%1 = Document No.';
        NoLinesErr: Label 'There are no lines to post for Book Loan %1.', Comment = '%1 = Document No.';
        AlreadyPostedErr: Label 'Book Loan %1 has already been posted.', Comment = '%1 = Document No.';

    local procedure Code()
    begin
        CheckBookLoan();

        PostedDocNo := GetPostedDocNo();

        InsertPostedHeader();
        PostLines();

        BookLoanHeader.Delete(true);
    end;

    local procedure CheckBookLoan()
    begin
        if BookLoanHeader.Status = BookLoanHeader.Status::Posted then
            Error(AlreadyPostedErr, BookLoanHeader."No.");

        if BookLoanHeader."Member No." = '' then
            Error(NoMemberErr, BookLoanHeader."No.");

        BookLoanLine.SetRange("Document No.", BookLoanHeader."No.");
        if BookLoanLine.IsEmpty() then
            Error(NoLinesErr, BookLoanHeader."No.");
    end;

    local procedure GetPostedDocNo(): Code[20]
    begin
        LibrarySetup.Get();
        LibrarySetup.TestField("Posted Book Loan Nos.");
        exit(NoSeries.GetNextNo(LibrarySetup."Posted Book Loan Nos."));
    end;

    local procedure InsertPostedHeader()
    begin
        PostedBookLoanHeader.Init();
        PostedBookLoanHeader.TransferFields(BookLoanHeader);
        PostedBookLoanHeader."No." := PostedDocNo;
        PostedBookLoanHeader."Posting Date" := Today();
        PostedBookLoanHeader.Insert(true);
    end;

    local procedure PostLines()
    begin
        BookLoanLine.SetRange("Document No.", BookLoanHeader."No.");
        if BookLoanLine.FindSet() then
            repeat
                InsertPostedLine(BookLoanLine);
                CreateLedgerEntry(BookLoanLine);
            until BookLoanLine.Next() = 0;
    end;

    local procedure InsertPostedLine(var SourceLine: Record "LIB Book Loan Line")
    begin
        PostedBookLoanLine.Init();
        PostedBookLoanLine.TransferFields(SourceLine);
        PostedBookLoanLine."Document No." := PostedDocNo;
        PostedBookLoanLine.Insert(true);
    end;

    local procedure CreateLedgerEntry(var SourceLine: Record "LIB Book Loan Line")
    begin
        BookLoanLedgerEntry.Init();
        BookLoanLedgerEntry."Book No." := SourceLine."Book No.";
        BookLoanLedgerEntry."Member No." := BookLoanHeader."Member No.";
        BookLoanLedgerEntry."Posting Date" := Today();
        BookLoanLedgerEntry."Document No." := PostedDocNo;
        BookLoanLedgerEntry."Entry Type" := BookLoanLedgerEntry."Entry Type"::Loan;
        BookLoanLedgerEntry.Quantity := SourceLine.Quantity;
        BookLoanLedgerEntry."Loan Date" := BookLoanHeader."Loan Date";
        BookLoanLedgerEntry."Due Date" := SourceLine."Due Date";
        BookLoanLedgerEntry.Insert(true);
    end;
}
