use Test;
use AttrX::Mooish;

plan 3;
throws-like 
    q<my class Foo1 { has $.bar is rw is mooish(:filter); }; Foo1.new.bar = 123; >,
    X::Method::NotFound,
    message => "No such method 'filter-bar' for invocant of type 'Foo1'",
    "missing filter method"
    ;

throws-like 
    q<my class Foo1 { has $.bar is rw is mooish(:trigger); }; Foo1.new.bar = 123; >,
    X::Method::NotFound,
    message => "No such method 'trigger-bar' for invocant of type 'Foo1'",
    "missing trigger method"
    ;

subtest "Nils", {
    plan 1;

    my $inst;

    my class Foo {
        has %.foo is mooish(:lazy);

        method build-foo { }
    }

    $inst = Foo.new;

    throws-like { $inst.foo },
                X::Hash::Store::OddNumber,
                :message(rx:s/^Odd number of elements found where hash initializer expected\:/),
                "hash build returns Nil";
}

done-testing;
# vim: ft=perl6
