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
    plan 8;
    my $inst;

    my class Foo1 {
        has Str @.bar is rw is mooish( :trigger );

        method trigger-bar ( $val ) {
        }
    }

    $inst = Foo1.new;
    $inst.bar = <a b c>;
    isa-ok $inst.bar, Array[Str], "attribute type preserved";
    is-deeply $inst.bar.Array, [<a b c>], "valid coercion to parametrized array";
    throws-like { $inst.bar = 1, 2, 3 },
        X::TypeCheck,
        "assignment of list of integers fails type check";
    is-deeply $inst.bar.Array, [<a b c>], "array attribute doesn't change after failed assignment";

    my class Foo2 {
        has Int %.bar is rw is mooish( :trigger );

        method trigger-bar ($val) {};
    }

    my Int %h;
    $inst = Foo2.new;
    $inst.bar = a=>1, b=>2;
    isa-ok $inst.bar, Hash[Int], "hash type preserved";
    is-deeply $inst.bar, Hash[Int].new( 'a', 1, 'b', 2 ), "valid coercion to parametrized hash";
    throws-like { $inst.bar = a=>"str", b=>"2" },
        X::TypeCheck,
        "assignment of pairs of Str values to Int hash fails type check";
    is-deeply $inst.bar, Hash[Int].new( 'a', 1, 'b', 2 ), "hash attribute doesn't change after failed assignment";
}

done-testing;
# vim: ft=perl6
