namespace Demo.Library;

using System.Utilities;

codeunit 70353 "LIB Book Return-Post (Yes/No)"
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
        BookReturnPost: Codeunit "LIB Book Return-Post";
        ConfirmMgmt: Codeunit "Confirm Management";
        ConfirmReturnQst: Label 'Do you want to process the return of the loaned books?';

    local procedure Code()
    begin
        if not ConfirmMgmt.GetResponseOrDefault(ConfirmReturnQst, false) then
            exit;

        BookReturnPost.Run(PostedBookLoanHeader);
    end;
}
