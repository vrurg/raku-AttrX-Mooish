use Test;
use AttrX::Mooish;

my $inst;
my class Foo1 {
    has $.bar is rw is mooish(:filter);

    multi method filter-bar ( Str $val ) {
        is $val, "a string value", "string value method";
    }

    multi method filter-bar ( Int $val where * > 100 ) {
        is $val, 314, "big integer value";
    }

    multi method filter-bar ( Int $val ) {
        is $val, 42, "integer value method";
    }
}

$inst = Foo1.new;

$inst.bar = "a string value";
$inst.bar = 42;
$inst.bar = 314;

done-testing;
# vim: ft=perl6
