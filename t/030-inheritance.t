use Test;
use AttrX::Mooish;

my %inst-records;

subtest "Inheritance basics", {
    plan 16;
    my $inst;

    class Bar1 {
        has $.initial is default(pi);
        has $.bar is rw is mooish(:lazy, :clearer, :predicate);
        has Int $.build-count = 0;
        #method BUILDALL (|) { note "Foo1 BUILDALL"; callsame }
        submethod BUILD { %inst-records{self.WHICH} = True; }
        submethod DESTROY { %inst-records{self.WHICH}:delete; }
        method build-bar { $!build-count++; $!initial }
        method direct-access { $!bar }
    }

    my class Foo1 is Bar1 {
    }

    $inst = Foo1.new;
    is $inst.bar, pi, "initialized by builder via accessor";

    my $inst2 = Foo1.new;
    is $inst2.direct-access, pi, "initialized by builder via direct access";

    $inst.bar = "foo-bar-baz";
    is $inst.bar, "foo-bar-baz", "set manually ok";
    is $inst2.bar, pi, "second object attribute unchanged";

    # So far, two object, one lazy attribute was initialized per each object.
    is mooish-obj-count, 2, "2 used slots correspond to attribute count";

    $inst = Foo1.new;
    for 1..2000 {
        my $v = $inst.bar;
    }
    is $inst.build-count, 1, "attribute build is executed only once";
    is mooish-obj-count, 3, "3 used slots correspond to attribute count";

    for 1..20000 {
        $inst = Foo1.new;
        my $v = $inst.bar;
    }

    is mooish-obj-count, %inst-records.keys.elems, "used slots correspond to number of objects survived GC";

    $inst.bar = "something different";
    is $inst.bar, "something different", "set before clear";
    $inst.clear-bar;
    is $inst.has-bar, False, "prefix reports no value";
    is $inst.bar, pi, "cleared and re-initialized";
    is $inst.has-bar, True, "prefix reports a value";

    class Bar2 {
        has $.bar is rw is mooish(:lazy, :clearer);
        has $.baz is rw;

        method build-bar { "not from new" }
    }

    my class Foo2 is Bar2 { }

    $inst = Foo2.new( bar => "from new",  baz => "from NEW" );
    is $inst.baz, "from NEW", "set from constructor";
    is $inst.bar, "from new", "set from constructor";
    $inst.clear-bar;
    is $inst.bar, "not from new", "reset and set not from constructor parameters";

    class Bar3 { 
        has $.bar is mooish(:lazy, builder => 'init-bar');
        method init-bar { "from init-bar" }
    }

    my class Foo3 is Bar3 {}

    $inst = Foo3.new;
    is $inst.bar, "from init-bar", "named builder works";
}

subtest "Overriding", {
    my $inst;

    # Base BarN classes from the previous test are used

    my class Foo1 is Bar1 {
        method build-bar {
            callsame;
            "but my string"
        }
    }

    $inst = Foo1.new;
    is $inst.bar, "but my string", "builder overridden";

    my class Foo3 is Bar3 {
        method init-bar { (callsame) ~ " with my suffix" }
    }

    $inst = Foo3.new;
    is $inst.bar, "from init-bar with my suffix", "named builder overridden";
}

subtest "Private", {
    plan 1;
    my $inst;

    my class Foo1 {
        has $!bar is mooish(:lazy);

        method !build-bar { "private value" }

        method get-bar { $!bar }
    }

    my class Foo2 is Foo1 {
        method run-test {
            is self.get-bar, "private value", "private attribute from parent class";
        }
    }

    $inst = Foo2.new;
    $inst.run-test;
}

done-testing;
# vim: ft=perl6
