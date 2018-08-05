use Test;
use AttrX::Mooish;
use Data::Dump;

my %inst-records;

subtest "Class Basics", {
    plan 16;
    my $inst;

    my class Foo1 {
        has $.initial is default(pi);
        has $.bar is rw is mooish(:lazy, :clearer, :predicate);
        has Int $.build-count = 0;
        #method BUILDALL (|) { note "Foo1 BUILDALL"; callsame }
        submethod BUILD { %inst-records{self.WHICH} = True; }
        submethod DESTROY { %inst-records{self.WHICH}:delete; }
        method build-bar { $!build-count++; $!initial }
        method direct-access { $!bar }
    }

    $inst = Foo1.new;
    is $inst.bar, pi, "initialized by builder via accessor";

    my $inst2 = Foo1.new;
    is $inst2.direct-access, pi, "initialized by builder via direct access";

    $inst.bar = "foo-bar-baz";
    is $inst.bar, "foo-bar-baz", "set manually ok";
    is $inst2.bar, pi, "second object attribute unchanged";

    # So far, two object, one lazy attribute was initialized per each object.
    is $inst.HOW.slots-used, 2, "2 used slots correspond to attribute count";

    $inst = Foo1.new;
    for 1..2000 {
        my $v = $inst.bar;
    }
    is $inst.build-count, 1, "attribute build is executed only once";
    is $inst.HOW.slots-used, 3, "3 used slots correspond to attribute count";

    for 1..20000 {
        $inst = Foo1.new;
        my $v = $inst.bar;
    }

    is $inst.HOW.slots-used, %inst-records.keys.elems, "used slots correspond to number of objects survived GC";

    $inst.bar = "something different";
    is $inst.bar, "something different", "set before clear";
    $inst.clear-bar;
    is $inst.has-bar, False, "prefix reports no value";
    is $inst.bar, pi, "cleared and re-initialized";
    is $inst.has-bar, True, "prefix reports a value";

    my class Foo2 {
        has $.bar is rw is mooish(:lazy, :clearer);
        has $.baz is rw;

        method build-bar { "not from new" }
    }

    $inst = Foo2.new( bar => "from new",  baz => "from NEW" );
    is $inst.baz, "from NEW", "set from constructor";
    is $inst.bar, "from new", "set from constructor";
    $inst.clear-bar;
    is $inst.bar, "not from new", "reset and set not from constructor parameters";

    my class Foo3 { 
        has $.bar is mooish(:lazy, builder => 'init-bar');
        method init-bar { "from init-bar" }
    }

    $inst = Foo3.new;
    is $inst.bar, "from init-bar", "named builder works";
}

subtest "Validating values", {
    plan 9;
    my $inst;

    my class Foo1 {
        has $.bar is rw is mooish(:lazy);
        has $.baz is mooish(:lazy);

        method build-bar { "is bar" }
        method build-baz { "is baz" }
    }

    $inst = Foo1.new;
    lives-ok { $inst.bar = "Fine" }, "assignment to RW attribute";
    throws-like { $inst.baz = "Bad"; }, 
                X::Assignment::RO, 
                message => 'Cannot modify an immutable Str (is baz)',
                "assignment to RO attribute failes";

    my class Foo2 {
        has Int $.bar is rw is mooish(:lazy);
        has $.baz is mooish(:lazy);

        method build-bar { 1234 }
        method build-baz { "is baz" }
    }
    $inst = Foo2.new;
    lives-ok { $inst.bar = 31415926 }, "assignment of same types";
    lives-ok { $inst.bar = Nil }, "assignment of Nil";
    throws-like { $inst.bar = "abc" },
                X::TypeCheck,
                message => q{Type check failed in assignment to attribute $!bar; expected "Int" but got "Str"},
                "assignment to a different attribute type";

    my class Foo3 {
        has Str:D $.bar is rw is mooish(:lazy) = "";

        method build-bar { "is bar" }
    }

    $inst = Foo3.new;
    lives-ok { $inst.bar = "a string" }, "assignment of defined value";
    throws-like { $inst.bar = Nil },
                X::TypeCheck,
                message => q{Type check failed in assignment to attribute $!bar; expected "Str:D:D" but got "Nil"},
                "assignment of Nil to a definite type attribute";

    my class Foo4 {
        has Str $.bar is rw is mooish(:lazy) where * ~~ /:i ^ a/;

        method build-bar { "a default value" }
    }

    $inst = Foo4.new;
    lives-ok { $inst.bar = "another value" }, "value assigned matches 'where' constraint";
    throws-like { $inst.bar = "not allowed" },
        X::TypeCheck,
        message => q{Type check failed in assignment to attribute $!bar; expected "<anon>" but got "Str"},
        "assignment of non-compliant value";

    #CATCH { note "Got exception ", $_.WHO; $_.throw}
}

subtest "Errors", {
    plan 1;
    my $inst;

    my class Foo4 {
        has Str $.bar is rw is mooish(:lazy) where * ~~ /:i ^ a/;

        method build-bar { "default value" }
    }

    throws-like { $inst = Foo4.new; $inst.bar },
        X::TypeCheck,
        message => q<Type check failed in assignment to attribute $!bar; expected "<anon>" but got "Str">,
        "value from builder don't conform 'where' constraint";

        #CATCH { note "Got exception ", $_.WHO; $_.throw}
}

done-testing;
# vim: ft=perl6
