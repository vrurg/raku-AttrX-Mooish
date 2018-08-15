unit module AttrX::Mooish:ver<0.2.904>:auth<github:vrurg>;
#use Data::Dump;

=begin pod
=head1 NAME

C<AttrX::Mooish> - extend attributes with ideas from Moo/Moose (laziness!)

=head1 SYNOPSIS

    use AttrX::Mooish;
    class Foo {
        has $.bar1 is mooish(:lazy, :clearer, :predicate) is rw;
        has $!bar2 is mooish(:lazy, :clearer, :predicate, :trigger);
        has Num $.bar3 is rw is mooish(:lazy, :filter);

        method build-bar1 {
            "lazy init value"
        }
        
        method !build-bar2 {
            "this is private mana!"
        }

        method !trigger-bar2 ( $value ) {
            # do something after attribute changed.
        }

        method build-bar3 {
            rand;
        }

        method filter-bar3 ( $value, *%params ) {
            if %params<old-value>:exists {
                # Only allow the value to grow
                return ( !%params<old-value>.defined || $value > %params<old-value> ) ?? $value !! %params<old-value>;
            }
            # Only allow inital values from 0.5 and higher
            return $value < 0.5 ?? Nil !! $value;
        }

        method baz {
            # Yes, works with private too! Isn't it magical? ;)
            "Take a look at the magic: «{ $!bar2 }»";
        }
    }

    my $foo = Foo.new;

    say $foo.bar1;
    say $foo.bar3.defined ?? "DEF" !! "UNDEF";
    for 1..10 { $foo.bar3 = rand; say $foo.bar3 }

The above would generate a output similar to the following:

    lazy init value
    UNDEF
    0.08662089602505263
    0.49049512098324255
    0.49049512098324255
    0.5983833081770437
    0.9367804461546302
    0.9367804461546302
    0.9367804461546302
    0.9367804461546302
    0.9367804461546302
    0.9367804461546302

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

C<Bool>, defines wether attribute is lazy. Can have C<Bool>, C<Str>, or C<Callable> value. The later two have the
same meaning, as for I<C<builder>> parameter.
=end item

=begin item
I<C<builder>>

Defines builder method for a lazy attribute. The value returned by the method will be used to initialize the attribute.

This parameter can have C<Str> or C<Callable> values or be not defined at all. In the latter case we expect a method
with a name composed of "I<build->" prefix followed by attribute name to be defined in our class. For example, for a
attribute named C<$!bar> the method name is expected to be I<build-bar>.

A string value defines builder's method name.

A callable value is used as-is and called an object method. For example:

    class Foo {
        has $.bar is mooish(:lazy, :builder( -> $ {"in-place"} );
    }

    $inst = Foo.new;
    say $inst.bar;

This would output 'I<in-place>'.
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
I<C<filter>>

A filter is a method which is executed right before storing a value to an attribute. What is returned by the method
will actually be stored into the attribute. This allows us to manipulate with a user-supplied value in any necessary
way.

The parameter can have values of C<Bool>, C<Str>, C<Callable>. All values are treated similarly to the C<builder>
parameter except that prefix 'I<filter->' is used when value is C<True>.

The filter method is passed with user-supplied value and two named parameters: C<attribute> with full attribute name;
and optional C<old-value> which could omitted if attribute has not been initialized yet. Otherwise C<old-value> contains
attribute value before the assignment.

B<Note> that it is not recommended for a filter method to use the corresponding attribute directly as it may cause
unforseen side-effects like deep recursion. The C<old-value> parameter is the right way to do it.
=end item

=begin item
I<C<trigger>>

A trigger is a method which is executed when a value is being written into an attribute. It gets passed with the stored
value as first positional parameter and named parameter C<attribute> with full attribute name. Allowed values for this
parameter are C<Bool>, C<Str>, C<Callable>. All values are treated similarly to the C<builder> parameter except that
prefix 'I<trigger->' is used when value is C<True>.

Trigger method is being executed right after changing the attribute value. If there is a C<filter> defined for the 
attribute then value will be the filtered one, not the initial.
=end item

## Public/Private

For all the trait parameters, if it is applied to a private attribute then all auto-generated methods will be private
too. The call-back style methods like C<builder> are expected to be private as well. I.e.:

=begin code
    class Foo {
        has $!bar is rw is mooish(:lazy, :clearer<reset-bar>, :predicate, :filter<wrap-filter>);

        method !build-bar { "a private value" }
        method baz {
            if self!has-bar {
                self!reset-bar;
            }
        }
        method !wrap-filter ( $value, :$attribute ) {
            "filtered $attribute: ($value)"
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
    #has Str $.message is rw;
}

class X::TypeCheck::MooishOption is X::TypeCheck {
    method expectedn {
        "Str or Callable";
    }
}

my %attr-data;

my role AttrXMooishClassHOW { ... }

my role AttrXMooishAttributeHOW {
    has $.base-name = self.name.substr(2);
    has $.lazy is rw = False;
    has $.builder is rw = 'build-' ~ $!base-name;
    has $.clearer is rw = False;
    has $.predicate is rw = False;
    has $.trigger is rw = False;
    has $.filter is rw = False;

    my %opt2prefix = clearer => 'clear', 
                     predicate => 'has',
                     builder => 'build',
                     trigger => 'trigger',
                     filter => 'filter',
                     ;

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

        for %helpers.keys -> $helper {
            my $helper-name = self!bool-str-meth-name( self."$helper"(), %opt2prefix{$helper} );

            X::Fatal.new( message => "Cannot install {$helper} {$helper-name}: method already defined").throw
                if type.^lookup( $helper-name );

            if $.has_accessor { # I.e. – public?
                type.^add_method( $helper-name, %helpers{$helper} );
            } else {
                type.^add_private_method( $helper-name, %helpers{$helper} );
            }
        }

        #note "+++ done composing attribute {$.name}";
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

    # force-default is true if attribute is set in .new( ) call
    method make-mooish ( Mu \instance, Bool $force-default ) {
        my $attr = self;
        my $obj-id = instance.WHICH;
        #note "Using obj ID:", $obj-id;
        #note "VAR:", instance.VAR;

        return if so %attr-data{$obj-id}{$.name};

        #note ">>> LAZIFYING ", $.name;

        my $default = self.get_value( instance );
        my $initialized = $default ~~ Positional | Associative ?? $default.elems !! $default.defined;

        if $initialized || $force-default {
            #note "=== Using initial value ", $default;
            self.store-value( $obj-id, $default );
        }
        #note "OBJ: ", Dump( instance );
        self.set_value( instance, 
            Proxy.new(
                FETCH => -> $ {
                    #note "FETCH of {$attr.name} for ", $obj-id;
                    self.build-attr( instance ) if so $.lazy;
                    %attr-data{$obj-id}{$attr.name}<value>;
                },
                STORE => -> $, $value is copy {
                    #note "STORE (", $obj-id, "): ", $value // '*undef*';
                    self.store-with-cb( instance, $value );
                }
            )
        );
        #note "Storing value in global hash";
        #%attr-data{$obj-id}{$.name}<value> = $default;

        #note "<<< DONE LAZIFYING ", $.name;
    }

    method invoke-filter ( Mu \instance, $value is rw ) {
        if $.filter {
            my $obj-id = instance.WHICH;
            my @invoke-params = $value, attribute => $.name;
            @invoke-params.push( 'old-value' => %attr-data{$obj-id}{$.name}<value> ) if self.is-set( $obj-id );
            $value = self.invoke-opt( instance, 'filter', @invoke-params, :strict );
        }
    }

    method store-with-cb ( Mu \instance, $value is rw ) {
        self.invoke-filter( instance, $value );
        self.store-value( instance.WHICH, $value );
        self.invoke-opt( instance, 'trigger', ( $value, :attribute($.name) ), :strict ) if $.trigger;
    }

    method store-value ( $obj-id, $value ) {
        self.check-value( $value );
        #note "store-value for ", $obj-id;
        %attr-data{$obj-id}{$.name}<value> = $value;
    }

    method is-set ( $obj-id) {
        %attr-data{$obj-id}{$.name}<value>:exists;
    }
    
    method clear-attr ( $obj-id ) {
        %attr-data{$obj-id}{$.name}:delete;
    }

    method invoke-opt ( Any \instance, Str $option, @params = (), :$strict = False ) {
        my $opt-value = self."$option"();
        my \type = $.package;

        return unless so $opt-value;
        
        my $method;

        given $opt-value {
            when Str | Bool {
                if $opt-value ~~ Bool {
                    die "Bug encountered: boolean option $option doesn't have a prefix assigned"
                        unless %opt2prefix{$option};
                    $opt-value = "{%opt2prefix{$option}}-{$.base-name}";
                }
                $method = $.has_accessor ?? instance.^find_method($opt-value) !! type.^find_private_method($opt-value);
                unless so $method {
                    # If no method found by name die if strict is on
                    return unless $strict;
                    X::Method::NotFound.new(
                        method => $opt-value,
                        private => !$.has_accessor,
                        typename => instance.WHO,
                    ).throw;
                }
            }
            when Callable {
                $method = $opt-value;
            }
            default {
                die "Bug encountered: $option is of unsupported type {$opt-value.WHO}";
            }
        }

        instance.$method(|(@params.Capture));
    }

    method build-attr ( Any \instance ) {
        my $obj-id = instance.WHICH;
        my $publicity = $.has_accessor ?? "public" !! "private";
        #note "&&& KINDA BUILDING FOR $publicity {$.name} on $obj-id";
        unless self.is-set( $obj-id ) {
            #note "&&& Calling builder {$!builder}";
            my $val = self.invoke-opt( instance, 'builder', :strict);
            self.store-with-cb( instance, $val );
            #note "Set ATTR";
        }
    }
}

my role AttrXMooishClassHOW {

    method compose ( Mu \type ) {
        state Bool $is-wrapped = False;
        unless $is-wrapped {
            $is-wrapped = True;
            Mu.^find_method( 'new', :no_fallback(1) ).wrap(
                my multi method new ( *%attrinit ) {
                    my $inst = callsame;
                    for $inst.^mro -> \type {
                        if type.HOW ~~ AttrXMooishClassHOW {
                            type.^on_create( $inst, %attrinit );
                        }
                    }
                    $inst
                }
            );
        }
        nextsame;
    }

    method add_method(Mu $obj, $name, $code_obj, :$nowrap=False) {
        #note "^^^ ADDING METHOD $name on {$obj.WHICH}";
        my $m = $code_obj;
        unless $nowrap {
            given $name {
                when <DESTROY> {
                    #note "^^^ WRAPPING DESTROY";
                    $m = my submethod DESTROY {
                        #note "&&& AUTOGEN DESTROY on {self.WHICH}";
                        %attr-data{self.WHICH}:delete;
                        self.&$code_obj;
                    }
                }
            }
        }
        nextwith($obj, $name, $m);
    }

    method install-stagers ( Mu \type ) {
        #note "+++ INSTALLING STAGERS {type.WHO} {type.HOW}";
        my %wrap-methods;
        
        %wrap-methods<DESTROY> = my submethod DESTROY {
            #note "&&& AUTOGEN DESTROY on {self.WHICH}";
            %attr-data{self.WHICH}:delete;
            nextsame;
        };

        for %wrap-methods.keys -> $method-name {
            my $orig-method = type.^declares_method( $method-name );
            if $orig-method {
                type.^find_method($method-name, :no_fallback(1)).wrap( %wrap-methods{$method-name} );
            }
            else {
                self.add_method( type, $method-name, %wrap-methods{$method-name}, :nowrap );
            }
        }

        type.^setup_finalization;
        type.^compose_repr;
        #note "+++ done installing stagers";
    }

    method create_BUILDPLAN ( Mu \type ) {
        #note "+++ create_BUILDPLAN";
        self.install-stagers( type );
        #note "+++ done create_BUILDPLAN";
        nextsame;
    }


    method on_create ( Mu \type, Mu \instance, Hash \attrinit ) {
        #note "ON CREATE";

        my @lazyAttrs = type.^attributes( :local(1) ).grep( AttrXMooishAttributeHOW );

        for @lazyAttrs -> $attr {
            #note "Found lazy attr {$attr.name} // {$attr.base-name}";
            $attr.make-mooish( instance, attrinit{$attr.base-name}:exists );
        }
    }

    method slots-used {
        #note Dump( $(%attr-data) );
        %attr-data.keys.elems;
    }
}

multi trait_mod:<is>( Attribute:D $attr, :$mooish! ) is export {
    $attr does AttrXMooishAttributeHOW;
    #note "Applying for {$attr.name} to ", $*PACKAGE.WHO;
    $*PACKAGE.HOW does AttrXMooishClassHOW unless $*PACKAGE.HOW ~~ AttrXMooishClassHOW;

    my $opt-list;

    given $mooish {
        when Bool { $opt-list = (); }
        when List { $opt-list = $mooish; }
        when Pair { $opt-list = [ $mooish ] }
        default { die "Unsupported mooish value type {$mooish.WHO}" }
    }

    for $opt-list.values -> $option {

        sub set-callable-opt ($opt, :$opt-name?) {
            my $option = $opt-name // $opt.key;
            X::TypeCheck::MooishOption.new(
                operation => "set option {$opt.key} of mooish trait",
                got => $opt.value,
                expected => Str,
            ).throw unless $opt.value ~~ Str | Callable;
            $attr."$option"() = $opt.value;
        }

        given $option {
            when Pair {
                given $option.key {
                    when 'lazy' {
                        $attr.lazy = $option.value;
                        set-callable-opt( opt-name => 'builder', $option ) unless $option.value ~~ Bool;
                    }
                    when 'builder' {
                        set-callable-opt( $option );
                    }
                    when 'trigger' | 'filter'  {
                        $attr."$_"() = $option.value;
                        set-callable-opt( $option ) unless $option.value ~~ Bool;
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
                X::Fatal.new( message => "Unsupported option type {$option.WHO}" ).throw;
            }
        }
    }
}

sub mooish-obj-count is export { %attr-data.keys.elems }

# Copyright (c) 2018, Vadim Belman <vrurg@cpan.org>
#
# Check the LICENSE file for the license

# vim: tw=120 ft=perl6
