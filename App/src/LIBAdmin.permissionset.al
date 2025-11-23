namespace Demo.Library;

permissionset 70300 "LIB Admin"
{
    Access = Public;
    Assignable = true;
    Caption = 'Library Admin', MaxLength = 30;
    Permissions = tabledata "LIB Author" = RIMD,
        tabledata "LIB Book" = RIMD,
        tabledata "LIB Book Loan Header" = RIMD,
        tabledata "LIB Book Loan Ledger Entry" = RIMD,
        tabledata "LIB Book Loan Line" = RIMD,
        tabledata "LIB Genre" = RIMD,
        tabledata "LIB Library Member" = RIMD,
        tabledata "LIB Library Setup" = RIMD,
        tabledata "LIB Posted Book Loan Header" = RIMD,
        tabledata "LIB Posted Book Loan Line" = RIMD,
        table "LIB Author" = X,
        table "LIB Book" = X,
        table "LIB Book Loan Header" = X,
        table "LIB Book Loan Ledger Entry" = X,
        table "LIB Book Loan Line" = X,
        table "LIB Genre" = X,
        table "LIB Library Member" = X,
        table "LIB Library Setup" = X,
        table "LIB Posted Book Loan Header" = X,
        table "LIB Posted Book Loan Line" = X,
        codeunit "LIB Book Loan-Post" = X,
        codeunit "LIB Book Loan-Post (Yes/No)" = X,
        codeunit "LIB Book Return-Post" = X,
        codeunit "LIB Book Return-Post (Yes/No)" = X,
        codeunit "LIB Translation Test Labels" = X,
        page "LIB Author Card" = X,
        page "LIB Author List" = X,
        page "LIB Book Card" = X,
        page "LIB Book List" = X,
        page "LIB Book Loan" = X,
        page "LIB Book Loan Ledger Entries" = X,
        page "LIB Book Loan List" = X,
        page "LIB Book Loan Subpage" = X,
        page "LIB Genre List" = X,
        page "LIB Library Member Card" = X,
        page "LIB Library Member List" = X,
        page "LIB Library Setup" = X,
        page "LIB Posted Book Loan Card" = X,
        page "LIB Posted Book Loan List" = X,
        page "LIB Posted Book Loan Subp." = X;
}