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
        314159;
    }
}

role FooRole {
    has $.baz is extended(:lazy);
}

class Foo2 does FooRole {
    has $.baz1 is extended(:lazy);
}

my $inst = Foo.new;
is $inst.bar, 31415926, "default from builder";
$inst.bar = 1234;
is $inst.bar, e, "changed value";
$inst.bar = Nil;
note "Nil assign:", $inst.bar;
is $inst.bar, Nil, "changed value to Nil";
say $inst.bar.defined;

done-testing;
# vim: ft=perl6
