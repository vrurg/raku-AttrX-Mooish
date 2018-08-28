use Test;
use AttrX::Mooish;

plan 10;

my $inst;

my class Foo1 {
    has Int $.foo is mooish( :lazy ) where * < 42;
    has %.bar is mooish( :lazy );
    has $.baz is mooish( :lazy );
    has @.fubar is mooish( :lazy );

    method build-bar {
        my @p = a=>1, b=>2;
        @p
    }

    method build-foo {
        "12";
    }

    method build-baz { pi }

    method build-fubar {
        { p => pi, e => e }
    }
}

$inst = Foo1.new;
is $inst.baz.WHAT, Num, "Any-typed have type from builder";
is $inst.baz, pi, "Any-typed attribute value";

is $inst.foo.WHAT, Int, "Right type";
is $inst.foo, 12, "Str -> Int";

is $inst.bar.WHAT, Hash, "associative attribute is hash";
is-deeply $inst.bar, {a=>1, b=>2}, "associative attribute value";

is $inst.fubar.WHAT, Array, "positional attribute is array";
is-deeply $inst.fubar.sort, [ p => pi, e => e ].sort, "positional attribute value";

my class Foo2 {
    has $.initial = 41;
    has Int $.foo is mooish( :lazy ) where * <= 42;

    method build-foo {
        $!initial;
    }
}

$inst = Foo2.new( initial => "42" );
is $inst.foo, 42, "subset is ok from initial conforming string value";

throws-like {
    $inst = Foo2.new( initial => 43.1 );
    $inst.foo;
}, X::TypeCheck,
   message => q<Type check failed in assignment to attribute $!foo; expected "<anon>" but got "Int">,
   "subset fails as expected from initial bad string value";

done-testing;
# vim: ft=perl6
