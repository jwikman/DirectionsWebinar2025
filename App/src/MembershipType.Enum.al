namespace Demo.Library;

enum 70370 "LIB Membership Type"
{
    Caption = 'Membership Type';
    Extensible = true;
    Access = Public;

    value(0; " ")
    {
        Caption = ' ', Locked = true;
    }
    value(1; Regular)
    {
        Caption = 'Regular';
    }
    value(2; Student)
    {
        Caption = 'Student';
    }
    value(3; Senior)
    {
        Caption = 'Senior';
    }
}
