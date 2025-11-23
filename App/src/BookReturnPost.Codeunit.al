namespace Demo.Library;

codeunit 70352 "LIB Book Return-Post"
{
    TableNo = "LIB Posted Book Loan Header";
    Access = Public;

    trigger OnRun()
    begin
        PostedBookLoanHeader.Copy(Rec);
        Code();
        Rec := PostedBookLoanHeader;
    end;

    var
        PostedBookLoanHeader: Record "LIB Posted Book Loan Header";
        PostedBookLoanLine: Record "LIB Posted Book Loan Line";
        BookLoanLedgerEntry: Record "LIB Book Loan Ledger Entry";

    local procedure Code()
    begin
        PostLines();
    end;

    local procedure PostLines()
    begin
        PostedBookLoanLine.SetRange("Document No.", PostedBookLoanHeader."No.");
        if PostedBookLoanLine.FindSet() then
            repeat
                CreateReturnLedgerEntry(PostedBookLoanLine);
            until PostedBookLoanLine.Next() = 0;
    end;

    local procedure CreateReturnLedgerEntry(var SourceLine: Record "LIB Posted Book Loan Line")
    begin
        BookLoanLedgerEntry.Init();
        BookLoanLedgerEntry."Book No." := SourceLine."Book No.";
        BookLoanLedgerEntry."Member No." := PostedBookLoanHeader."Member No.";
        BookLoanLedgerEntry."Posting Date" := Today();
        BookLoanLedgerEntry."Document No." := PostedBookLoanHeader."No.";
        BookLoanLedgerEntry."Entry Type" := BookLoanLedgerEntry."Entry Type"::Return;
        BookLoanLedgerEntry.Quantity := -SourceLine.Quantity;
        BookLoanLedgerEntry."Loan Date" := PostedBookLoanHeader."Loan Date";
        BookLoanLedgerEntry."Due Date" := SourceLine."Due Date";
        BookLoanLedgerEntry."Return Date" := Today();
        BookLoanLedgerEntry.Insert(true);
    end;
}
