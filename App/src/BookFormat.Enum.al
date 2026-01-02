namespace Demo.Library;

enum 70373 "LIB Book Format"
{
    Caption = 'Book Format';
    Extensible = true;
    Access = Public;

    value(0; " ")
    {
        Caption = ' ', Locked = true;
    }
    value(1; Paperback)
    {
        Caption = 'Paperback';
    }
    value(2; Hardback)
    {
        Caption = 'Hardback';
    }
    value(3; eBook)
    {
        Caption = 'eBook';
    }
    value(4; "Audio Book")
    {
        Caption = 'Audio Book';
    }
}
