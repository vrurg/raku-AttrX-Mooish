use v6.d;
class CustomClassHOW is Metamodel::ClassHOW {}
class CustomRoleHOW is Metamodel::ParametricRoleHOW {}

PROCESS::<$ATTRX-MOOISH-CUSTOM-TESTING> = True;

my package EXPORTHOW {
    package SUPERSEDE {
        constant class = CustomClassHOW;
        constant role = CustomRoleHOW;
    }
}