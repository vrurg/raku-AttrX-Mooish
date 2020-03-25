use v6;
use Test;
use AttrX::Mooish;

plan 2;

subtest "Concurrent instantiation" => {
    plan 4;

    my $repeats = 10000;
    my $workers = 20;

    my class Foo {
        has Int $.foo is mooish(:lazy, :clearer, :predicate);

        method build-foo { 42 }
    }

    my $cnt-lock = Lock.new;

    my $inits-total = 0;
    my $reinits-total = 0;
    my $clears-total = 0;
    my $predicate-total = 0;

    sub run-test {
        my $inits-ok = 0;
        my $reinits-ok = 0;
        my $clears-ok = 0;
        my $predicate-ok = 0;
        for ^$repeats {
            my $inst = Foo.new;
            ++$predicate-ok unless $inst.has-foo;
            ++$inits-ok if $inst.foo == 42;
            ++$predicate-ok if $inst.has-foo;
            ++$clears-ok if try $inst.clear-foo;
            ++$predicate-ok unless $inst.has-foo;
            ++$reinits-ok if $inst.foo == 42;
        }
        $cnt-lock.protect: {
            $inits-total += $inits-ok;
            $reinits-total += $reinits-ok;
            $clears-total += $clears-ok;
            $predicate-total += $predicate-ok;
        }
    }

    my @p;
    for ^$workers {
        @p.push: start {
            run-test;
        }
    }

    await @p;

    my $expected = $workers * $repeats;
    is $inits-total, $expected, "all inits passed";
    is $reinits-total, $expected, "all re-inits passed";
    is $predicate-total, 3 * $expected, "all predicates passed";
    is $clears-total, $expected, "all clears passed";
}

subtest "Concurrent lazy builds" => {
    plan 4;
    my class Foo {
        has $.foo is mooish(:lazy, :clearer);
        has atomicint $.builds-ran = 0;

        method build-foo {
            ++⚛$!builds-ran;
        }

        method reset {
            self.clear-foo;
            $!builds-ran ⚛= 0;
        }
    }

    sub access-test($inst) {
        my $starter = Promise.new;

        my @workers;
        my @w-ready;
        for ^100 {
            @w-ready.push: my $ready = Promise.new;
            @workers.push: start {
                $ready.keep(True);
                await $starter;
                # Initialize concurrent read from the attribute.
                my $v = $inst.foo;
            }
        }

        await @w-ready;
        $starter.keep(True);
        await @workers;
        is $inst.builds-ran, 1, "build was ran exactly once per instance";
        is $inst.foo, 1, "initialized with the number of builds invoked";
    }

    my $foo = Foo.new;
    my $*AXM-DEBUG = 1;
    access-test($foo);
    $foo.reset;
    access-test($foo);
}

done-testing;
