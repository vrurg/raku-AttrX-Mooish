NAME
====

`AttrX::Mooish` - extend attributes with ideas from Moo/Moose (laziness!)

SYNOPSIS
========

    class Foo {
        has $.bar1 is mooish(:lazy, :clearer, :predicate) is rw;
        has $!bar2 is mooish(:lazy, :clearer, :predicate) is rw;
        has $.bar3 is rw is mooish(:lazy);

        method build-bar1 {
            "lazy init value"
        }
        
        method !build-bar2 {
            "this is private mana!"
        }

        method build-bar3 {
            .rand < 0.5 ?? Nil !! pi;
        }

        method baz {
            # Yes, works with private too! Isn't it magical? ;)
            "Take a look at the magic: «{ $!bar2 }»";
        }
    }

    my $foo = Foo.new;

    say $foo.bar1;
    say $foo.bar3.defined ?? "DEF" !! "UNDEF";

DESCRIPTION
===========

This module is aiming at providing some functionality we're all missing from Moo/Moose. For now it implements laziness with accompanying methods. But more may come in the future.

What makes this module different from previous versions one could find in the Perl6 modules repository is that it implements true laziness allowing `Nil` to be a first-class value of a lazy attribute. In other words, if you look at the [#SYNOPSIS](#SYNOPSIS) section, `$.bar3` value could randomly be either undefined or 3.1415926.

Laziness for beginners
----------------------

This section is inteded for beginners and could be skipped by experienced lazybones.

### What is "lazy attribute"

As always, more information could be found by Google. In few simple words: a lazy attribute is the one which gets its first value on demand, i.e. – on first read operation. Consider the following code:

    class Foo {
        has $.bar is mooish(:lazy :predicate);

        method build-bar { π }
    }

    my $foo = Foo.new
    say $foo.has-bar; # False
    say $foo.bar;     # 3.1415926...
    say $foo.has-bar; # True

### When is it useful?

Laziness becomes very handy in cases where intializing an attribute is very expensive operation yet it is not certain if attribute is gonna be used later or not. For example, imagine a monitoring code which raises an alert when a failure is detected:

    class Monitor {
        has $.notifier;
        has $!failed-object;
       
        submethod BUILD {
            $!notifier = Notifier.new;
        }

        method report-failure {
            $.notifier.alert( :$!failed-object );
        }

        ...
    }

Now, imagine that notifier is a memory-consuming object, which is capable of sending notification over different kinds of media (SMTP, SMS, messengers, etc...). Besides, preparing handlers for all those media takes time. Yet, failures are rare and we may need the object, say, once in 10000 times. So, here is the solution:

    class Monitor {
        has $.notifier is mooish(:lazy);
        has $!failed-object;

        method build-notifier { Notifier.new( :$!failed-object ) }

        method report-failure {
            $.notifier.alert;
        }

        ...
    }

Now, it would only be created when we really need it.

Such approach also works well in interactive code where many wuch objects are created only the moment a user action requires them. This way overall responsiveness of a program could be significally incresed so that instead of waiting long once a user would experience many short delays which sometimes are even hard to impossible to be aware of.

Laziness has another interesting application in the area of taking care of attribute dependency. Say, `$.bar1` value depend on `$.bar2`, which, in turn, depends either on `$.bar3` or `$.bar4`. In this case instead of manually defining the order of initialization in a `BUILD` submethod, we just have the following code in our attribute builders:

    method build-bar2 {
        if $some-condition {
            return self.prepare( $.bar3 );
        }
        self.prepare( $.bar4 );
    }

This module would take care of the rest.

USAGE
=====

The [#SYNOPSIS](#SYNOPSIS) is a very good example of how to use the trait `mooish`.

Trait parameters
----------------

  * *`lazy`*

    `Bool`, defines wether attribute is lazy.

  * *`predicate`*

    Could be `Bool` or `Str`. When defined trait will add a method to determine if attribute is set or not. Note that it doesn't matter wether it was set with a builder or by an assignment.

    If parameter is `Bool` *True* then method name is made of attribute name prefixed with _has-_. See [#What is "lazy attribute"](#What is "lazy attribute") section for example.

    If parameter is `Str` then the string contains predicate method name:

                has $.bar is mooish(:lazy :predicate<bar-is-ready>);
                ...
                method baz {
                    if self.bar-is-ready {
                        ...
                    }
                }

  * *`clearer`*

    Could be `Bool` or `Str`. When defined trait will add a method to reset the attribute to uninitialzed state. This is not equivalent to *undefined* because, as was stated above, `Nil` is a valid value of initialized attribute.

    Similarly to *`predicate`*, when *True* the method name is formed with _clear-_ prefix followed by attribute's name. A `Str` value defines method name:

                has $.bar is mooish(:lazy, :clearer<reset-bar>, :predicate);
                ...
                method baz {
                    $.bar = "a value";
                    say self.has-bar;  # True
                    self.reset-bar;
                    say self.has-bar;  # False
                }

  * *`builder`*

    Defines the name of attribute builder method. If not defined then lazyness would look for a user-defined method with name formed of _build-_ prefix followed by attribute name. *`builder`* lets user change it to whatever he considers appropriate.

    *Use of a `Routine` object as a `builder` value is planned but not implemented yet.*

For all the trait parameters, if it is applied to a private attribute then all auto-generated methods will be private too. The builder method is expected to be private as well. I.e.:

        class Foo {
            has $!bar is rw is mooish(:lazy, :clearer<reset-bar>, :predicate);

            method !build-bar { "a private value" }
            method baz {
                if self!has-bar {
                    self!reset-bar;
                }
            }
        }

Some magic
----------

Note that use of this trait doesn't change attribute accessors. More than that, accessors are not required for private attributes. Consider the `$!bar2` attribute from [#SYNOPSIS](#SYNOPSIS).

CAVEATS
=======

This module is using manual type checking for attributes with constraints. This could result in outcome different from default Perl6 behaviour.

Due to the magical nature of attribute behaviour conflicts with other traits are possible but not yet known to the author.

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the LICENSE file in this distribution.

