unit module AttrX::Mooish:ver<0.0.1>:auth<github:vrurg>;
#use Data::Dump;

=begin pod
=head1 NAME

C<AttrX::Mooish> - extend attributes with ideas from Moo/Moose (laziness!)

=head1 SYNOPSIS

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

=head1 DESCRIPTION

This module is aiming at providing some functionality we're all missing from Moo/Moose. For now it implements laziness
with accompanying methods. But more may come in the future.

What makes this module different from previous versions one could find in the Perl6 modules repository is that it
implements true laziness allowing C<Nil> to be a first-class value of a lazy attribute. In other words, if you look at
the L<#SYNOPSIS> section, C<$.bar3> value could randomly be either undefined or 3.1415926.

=head2 Laziness for beginners

This section is inteded for beginners and could be skipped by experienced lazybones.

=head3 What is "lazy attribute"

As always, more information could be found by Google. In few simple words: a lazy attribute is the one which gets its
first value on demand, i.e. – on first read operation. Consider the following code:

    class Foo {
        has $.bar is mooish(:lazy :predicate);

        method build-bar { π }
    }

    my $foo = Foo.new
    say $foo.has-bar; # False
    say $foo.bar;     # 3.1415926...
    say $foo.has-bar; # True

=head3 When is it useful?

Laziness becomes very handy in cases where intializing an attribute is very expensive operation yet it is not certain
if attribute is gonna be used later or not. For example, imagine a monitoring code which raises an alert when a failure
is detected:

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

Now, imagine that notifier is a memory-consuming object, which is capable of sending notification over different kinds
of media (SMTP, SMS, messengers, etc...). Besides, preparing handlers for all those media takes time. Yet, failures are
rare and we may need the object, say, once in 10000 times. So, here is the solution:

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

Such approach also works well in interactive code where many wuch objects are created only the moment a user action
requires them. This way overall responsiveness of a program could be significally incresed so that instead of waiting
long once a user would experience many short delays which sometimes are even hard to impossible to be aware of.

Laziness has another interesting application in the area of taking care of attribute dependency. Say, C<$.bar1> value
depend on C<$.bar2>, which, in turn, depends either on C<$.bar3> or C<$.bar4>. In this case instead of manually defining 
the order of initialization in a C<BUILD> submethod, we just have the following code in our attribute builders:

    method build-bar2 {
        if $some-condition {
            return self.prepare( $.bar3 );
        }
        self.prepare( $.bar4 );
    }

This module would take care of the rest.

=head1 USAGE

The L<#SYNOPSIS> is a very good example of how to use the trait C<mooish>.

=head2 Trait parameters

=begin item
I<C<lazy>>

C<Bool>, defines wether attribute is lazy.
=end item

=begin item
I<C<predicate>>

Could be C<Bool> or C<Str>. When defined trait will add a method to determine if attribute is set or not. Note that
it doesn't matter wether it was set with a builder or by an assignment.

If parameter is C<Bool> I<True> then method name is made of attribute name prefixed with U<has->. See
L<#What is "lazy attribute"> section for example.

If parameter is C<Str> then the string contains predicate method name:

=begin code
        has $.bar is mooish(:lazy :predicate<bar-is-ready>);
        ...
        method baz {
            if self.bar-is-ready {
                ...
            }
        }
=end code
=end item

=begin item
I<C<clearer>>

Could be C<Bool> or C<Str>. When defined trait will add a method to reset the attribute to uninitialzed state. This is
not equivalent to I<undefined> because, as was stated above, C<Nil> is a valid value of initialized attribute.

Similarly to I<C<predicate>>, when I<True> the method name is formed with U<clear-> prefix followed by attribute's name.
A C<Str> value defines method name:

=begin code
        has $.bar is mooish(:lazy, :clearer<reset-bar>, :predicate);
        ...
        method baz {
            $.bar = "a value";
            say self.has-bar;  # True
            self.reset-bar;
            say self.has-bar;  # False
        }
=end code
=end item

=begin item
I<C<builder>>

Defines the name of attribute builder method. If not defined then lazyness would look for a user-defined method
with name formed of U<build-> prefix followed by attribute name. I<C<builder>> lets user change it to whatever he
considers appropriate.

I<Use of a C<Routine> object as a C<builder> value is planned but not implemented yet.>
=end item

For all the trait parameters, if it is applied to a private attribute then all auto-generated methods will be private
too. The builder method is expected to be private as well. I.e.:

=begin code
    class Foo {
        has $!bar is rw is mooish(:lazy, :clearer<reset-bar>, :predicate);

        method !build-bar { "a private value" }
        method baz {
            if self!has-bar {
                self!reset-bar;
            }
        }
    }
=end code

=head2 Some magic

Note that use of this trait doesn't change attribute accessors. More than that, accessors are not required for private 
attributes. Consider the C<$!bar2> attribute from L<#SYNOPSIS>.

=head1 CAVEATS

This module is using manual type checking for attributes with constraints. This could result in outcome different from
default Perl6 behaviour.

Due to the magical nature of attribute behaviour conflicts with other traits are possible. None is known to the author
yet.

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

class X::Fatal is Exception {
    has Str $.message is rw;
}

my %attr-data;

my role AttrXMooishClassHOW { ... }

my role AttrXMooishAttributeHOW {
    has $.base-name = self.name.substr(2);
    has $.lazy is rw = False;
    has $.builder is rw = 'build-' ~ $!base-name;
    has $.clearer is rw = False;
    has $.predicate is rw = False;

    method !bool-str-meth-name( $opt, Str $prefix ) {
        $opt ~~ Bool ?? $prefix ~ '-' ~ $!base-name !! $opt;
    }

    method compose ( Mu \type ) {

        #note "+++ composing {$.name} on {type.WHO} {type.WHICH}";

        unless type.HOW ~~ AttrXMooishClassHOW {
            #note "Installing AttrXMooishClassHOW on {type.WHICH}";
            type.HOW does AttrXMooishClassHOW;
        }

        callsame;

        my $attr = self;
        my %helpers = 
            clearer => method { $attr.clear-attr( self.WHICH ); },
            predicate => method { so $attr.is-set( self.WHICH ); },
            ;
        my %helper-prefix = clearer => 'clear', predicate => 'has';

        for %helpers.keys -> $helper {
            my $helper-name = self!bool-str-meth-name( self."$helper"(), %helper-prefix{$helper} );

            X::Fatal.new( message => "Cannot install {$helper} {$helper-name}: method already defined").throw
                if type.^lookup( $helper-name );

            if $.has_accessor { # I.e. – public?
                type.^add_method( $helper-name, %helpers{$helper} );
            } else {
                type.^add_private_method( $helper-name, %helpers{$helper} );
            }
        }
    }

    method check-value ( $value ) {
        #note "CHECKING VALUE:", $value;
        my $operation = "assignment to attribute {$.name}";
        if !$value.defined {
            #note "undefined value";
            if $.type.HOW ~~ Metamodel::DefiniteHOW {
                #note "Type with definite HOW";
                #note "Type {$.type.^definite ?? "IS" !! "ISN'T"} definite";
                X::TypeCheck.new(
                    :$operation,
                    got => 'Nil',
                    expected => "{$.type.^name}:D",
                ).throw if $.type.^definite;
            }
        }
        else {
            X::TypeCheck.new(
                :$operation,
                got => ~$value.WHO,
                expected => ~$.type.WHO,
             ).throw unless $value ~~ $.type;
        }
    }

    method make-lazy ( Mu \instance ) {
        my $attr = self;
        my $obj-id = instance.WHICH;
        #note "Using obj ID:", $obj-id;

        return if so %attr-data{$obj-id}{$.name};

        #note ">>> LAZIFYING ", $.name;

        my $default = self.get_value( instance );
        #note "Initial value is ", $default;
        #note "OBJ: ", Dump( instance );
        self.set_value( instance, 
            Proxy.new(
                FETCH => -> $ {
                    #note "FETCH of {$attr.name} for ", $obj-id;
                    self.build-attr( instance );
                    %attr-data{$obj-id}{$attr.name}<value>;
                },
                STORE => -> $, $value {
                    #note "STORE (", $obj-id, "): ", $value // '*undef*';
                    self.store-value( $obj-id, $value );
                }
            )
        );
        #note "Storing value in global hash";
        #%attr-data{$obj-id}{$.name}<value> = $default;

        #note "<<< DONE LAZIFYING ", $.name;
    }

    method store-value ( $obj-id, $value ) {
        self.check-value( $value );
        #note "store-value for ", $obj-id;
        %attr-data{$obj-id}{$.name}<value> = $value;
    }

    method is-set ( $obj-id) {
        %attr-data{$obj-id}{$.name}<value>;
    }
    
    method clear-attr ( $obj-id ) {
        %attr-data{$obj-id}{$.name}:delete;
    }

    method build-attr ( Any \instance ) {
        my $obj-id = instance.WHICH;
        my \type = $.package;
        my $publicity = $.has_accessor ?? "public" !! "private";
        unless self.is-set( $obj-id ) {
            #note "&&& Calling builder {$!builder}";
            my $builder = $.has_accessor ?? instance.^find_method($!builder) !! type.^find_private_method($!builder);
            X::Method::NotFound.new(
                method => $!builder,
                private => !$.has_accessor,
                typename => instance.WHO,
            ).throw unless so $builder;
            my $val = instance.&$builder();
            #note "Builder-generated value: ", $val, " -- for ", $obj-id;
            self.store-value( $obj-id, $val );
            #note "Set ATTR";
        }
    }
}

my role AttrXMooishClassHOW {

    method inject-method ( Mu \type, $name, &method ) {
        #note "Injecting $name on {type.WHICH} // {type.HOW}";
        if  type.^declares_method( $name ) {
            my &orig-method = type.^lookup( $name );
            #note "    -> by wrapping of {&orig-method.WHICH} from {&orig-method.package.WHICH}";
            &orig-method.wrap( &method );
        } else {
            #note "    -> by adding {&method.WHICH}";
            type.^add_method( $name, &method );
        }
    }

    method install-stagers ( Mu \type ) {
        #note "&&& INSTALLING STAGERS {type.WHO} {type.HOW}";
        my %wrap-methods;
        
        #note "MRO:", type.^mro;
        my \ancestor = type.^mro[1];
        #note "ANCESTOR:", ancestor.WHO;
        my &ancestor-buildall = ancestor.^lookup('BUILDALL');
        %wrap-methods<BUILDALL> = method BUILDALL (|c) {
            #note "&&& AUTOGEN BUILD obj:{self.WHICH} type:{self.WHAT.WHICH} // {self.HOW} &&&";
            type.HOW.on_create( self );
            #note "&&& nextsame: ", nextcallee.WHICH, " // ancestor method: ", &ancestor-buildall.WHICH;
            callsame;
            #note "&&& calling ancestor's method";
            # XXX Workaround for inheritance issue of wrapped methods
            # Reported in https://github.com/rakudo/rakudo/issues/2178
            self.&ancestor-buildall(|c);
        }

        %wrap-methods<DESTROY> = submethod {
            #note "&&& AUTOGEN DESTROY on {self.WHICH}";
            %attr-data{self.WHICH}:delete;
            nextsame;
        };

        for %wrap-methods.keys -> $method-name {
            self.inject-method( type, $method-name, %wrap-methods{$method-name} );
        }

        type.^setup_finalization;
        type.^compose_repr;
    }

    method create_BUILDPLAN ( Mu \type ) {
        self.install-stagers( type );
        nextsame;
    }

    method on_create ( Mu \instance ) {
        #note "ON CREATE";

        my @lazyAttrs = self.attributes( self ).grep( AttrXMooishAttributeHOW );

        for @lazyAttrs -> $attr {
            #note "Found lazy attr ", $attr.name;
            $attr.make-lazy( instance );
        }
    }

    method slots-used {
        #note Dump( $(%attr-data) );
        %attr-data.keys.elems;
    }
}

multi trait_mod:<is>( Attribute:D $attr, :$mooish! ) is export {
    $attr does AttrXMooishAttributeHOW;
    #note "Applying to ", $*PACKAGE.WHO;
    $*PACKAGE.HOW does AttrXMooishClassHOW unless $*PACKAGE.HOW ~~ AttrXMooishClassHOW;

    my $opt-list = $mooish ~~ List ?? $mooish !! @$mooish;
    for $opt-list.values -> $option {
        given $option {
            when Pair {
                given $option.key {
                    when 'lazy' {
                        $attr.lazy = so $option<lazy>;
                    }
                    when 'builder' {
                        X::Fatal.new( message => "Only builder name (Str) is currently supported for attribute {$attr.name}" ).throw unless $option<builder> ~~ Str;
                        $attr.builder = $option<builder>;
                    }
                    when 'clearer' | 'predicate' {
                        my $opt = $_;
                        given $option{$opt} {
                            X::Fatal.new( message => "Unsupported {$opt} type of {.WHAT} for attribute {$attr.name}; can only be Bool or Str" ).throw
                                unless $_ ~~ Bool | Str;
                            $attr."$opt"() = $_;
                        }
                    }
                    default {
                        X::Fatal.new( message => "Unknown named option {$_}" ).throw;
                    }
                }
            }
            default {
                X::Fatal.new( message => "Unknown option type {$option.WHO}" ).throw;
            }
        }
    }
}

sub mooish-obj-count is export { %attr-data.keys.elems }

# Copyright (c) 2018, Vadim Belman <vrurg@cpan.org>
#
# Check the LICENSE file for the license

# vim: tw=120 ft=perl6
