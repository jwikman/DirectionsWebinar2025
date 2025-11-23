namespace Demo.Library;

enum 70372 "LIB Book Loan Entry Type"
{
    Caption = 'Book Loan Entry Type';
    Extensible = true;
    Access = Public;

    value(0; " ")
    {
        Caption = ' ', Locked = true;
    }
    value(1; Loan)
    {
        Caption = 'Loan';
    }
    value(2; Return)
    {
        Caption = 'Return';
    }
}
