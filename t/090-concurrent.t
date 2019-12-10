use v6;
use Test;
use AttrX::Mooish;

plan 4;

class Foo {
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
    for ^10000 {
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
for ^20 {
    @p.push: start {
        run-test;
    }
}

await @p;

is $inits-total, 200000, "all inits passed";
is $reinits-total, 200000, "all re-inits passed";
is $predicate-total, 600000, "all predicates passed";
is $clears-total, 200000, "all clears passed";

done-testing;
