use Test;
use AttrX::Mooish;

plan 2;
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

done-testing;
# vim: ft=perl6
