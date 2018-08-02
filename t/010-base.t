use Test;
use AttrX::Extended;
use Data::Dump;

class Foo {
    has Int $.bar is rw is extended(builder=>'init-bar', lazy=>1, :clearer);
    has Int $.attr is rw; 
    has $.build-count is rw = 0;

    method init-bar {
        note "init-bar()";
        $!build-count++;
        31415926;
    }

    method direct {
        note "### bar:", $!bar;
    }
}

role FooRole {
    has $.baz is rw is extended(:lazy, builder => "build-baz");

    method build-baz {
        note "build-baz()";
        return pi;
    }
}

class Foo2 does FooRole {
    has Rat $.baz1 is extended(:lazy);
    has $!baz2 is extended(:lazy);

    method t {
        note "=== baz2:", $!baz2;
        note "=== baz1:", $.baz1;
        note "=== baz :", $.baz;
        $.baz1 = 1.0;
        note "=== baz1:", $.baz1;
        note "=== !baz1:", $!baz1;
        $.baz1 = Nil;
    }

    method build-baz2 {
        note "Building !baz2";
        "ABCDEF";
    }

    method build-baz1 {
        note "Building baz1";
        12.12;
    }
}

note "CREATING INSTANCE";
my $inst = Foo.new;
note "CREATED";
$inst.direct;
is $inst.bar, 31415926, "default from builder";
$inst.bar = 1234;
is $inst.bar, e, "changed value";
#$inst.bar = Nil;
note "Nil assign:", $inst.bar;
is $inst.bar, Nil, "changed value to Nil";
say $inst.bar.defined;

$inst = Foo2.new;
$inst.t;

done-testing;
# vim: ft=perl6
