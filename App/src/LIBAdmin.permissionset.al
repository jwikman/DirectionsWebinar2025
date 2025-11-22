namespace Demo.Library;

permissionset 70300 "LIB Admin"
{
    Access = Public;
    Assignable = true;
    Caption = 'Library Admin', MaxLength = 30;
    Permissions = tabledata "LIB Author" = RIMD,
        tabledata "LIB Book" = RIMD,
        tabledata "LIB Genre" = RIMD,
        tabledata "LIB Library Member" = RIMD,
        tabledata "LIB Library Setup" = RIMD,
        table "LIB Author" = X,
        table "LIB Book" = X,
        table "LIB Genre" = X,
        table "LIB Library Member" = X,
        table "LIB Library Setup" = X,
        page "LIB Author Card" = X,
        page "LIB Author List" = X,
        page "LIB Book Card" = X,
        page "LIB Book List" = X,
        page "LIB Genre List" = X,
        page "LIB Library Member Card" = X,
        page "LIB Library Member List" = X,
        page "LIB Library Setup" = X;
}