use Test;
use AttrX::Mooish;

plan 2;

subtest "Basics", {
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
        message => q<Type check failed in assignment to attribute $!foo; expected <anon> but got Int (43)>,
        "subset fails as expected from initial bad string value";
}

subtest "Typed", {
    plan 2;
    my $inst;

    my class Foo1 {
        has Str @.bar is rw is mooish( :trigger );

        method trigger-bar ( $val ) {
        }
    }

    $inst = Foo1.new;
    $inst.bar = <a b c>;
    is-deeply $inst.bar, [<a b c>], "valid coercion to typed array";
    throws-like { $inst.bar = 1, 2, 3 },
        X::TypeCheck,
        "assignment of list of integers fails type check";

    #`[ Don't test hashes as type checking doesn't work for them in any more complicated situation than %h = {a=>1, b=>2}
    my class Foo2 {
        has Int %.bar is rw is mooish( :trigger );

        method trigger-bar ($val) {};
    }

    my Int %h;
    $inst = Foo2.new;
    $inst.bar = a=>1, b=>2;
    note $inst.bar;
    $inst.bar = a=>"str", b=>"2";
    note $inst.bar;
    ]
}

done-testing;
# vim: ft=perl6
