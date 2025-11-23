namespace Demo.Library;

enum 70371 "LIB Book Loan Status"
{
    Caption = 'Book Loan Status';
    Extensible = true;
    Access = Public;

    value(0; " ")
    {
        Caption = ' ', Locked = true;
    }
    value(1; Open)
    {
        Caption = 'Open';
    }
    value(2; Posted)
    {
        Caption = 'Posted';
    }
}
