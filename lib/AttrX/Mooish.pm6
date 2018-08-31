unit module AttrX::Mooish:ver<0.4.3>:auth<github:vrurg>;
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
implements true laziness allowing I<Nil> to be a first-class value of a lazy attribute. In other words, if you look at
the L<#SYNOPSIS> section, C<$.bar3> value could randomly be either undefined or 3.1415926.

=head2 Laziness for beginners

This section is inteded for beginners and could be skipped by experienced lazybones.

=head3 What is "lazy attribute"

As always, more information could be found by Google. In few simple words: a lazy attribute is the one which gets its
first value on demand, i.e. – on first read operation. Consider the following code:

    class Foo {
        has $.bar is mooish(:lazy, :predicate);

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

A callable value is used as-is and invoked as an object method. For example:

    class Foo {
        has $.bar is mooish(:lazy, :builder( -> $,*% {"in-place"} );
    }

    $inst = Foo.new;
    say $inst.bar;

This would output 'I<in-place>'.

*Note* the use of slurpy C<*%> in the pointy block. Read about callback parameters below.
=end item

=begin item
I<C<predicate>>

Could be C<Bool> or C<Str>. When defined trait will add a method to determine if attribute is set or not. Note that
it doesn't matter wether it was set with a builder or by an assignment.

If parameter is C<Bool> I<True> then method name is made of attribute name prefixed with U<has->. See
L<#What is "lazy attribute"> section for example.

If parameter is C<Str> then the string contains predicate method name:

=begin code
        has $.bar is mooish(:lazy, :predicate<bar-is-ready>);
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
not equivalent to I<undefined> because, as was stated above, I<Nil> is a valid value of initialized attribute.

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
parameter except that prefix 'I<filter->' is used when value is I<True>.

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
prefix 'I<trigger->' is used when value is I<True>.

Trigger method is being executed right after changing the attribute value. If there is a C<filter> defined for the 
attribute then value will be the filtered one, not the initial.
=end item

=begin item
I<C<composer>>

This is a very specific option mostly useful until role C<COMPOSE> phaser is implemented. Method of this option is
called upon class composition time.
=end item

=head2 Public/Private

For all the trait parameters, if it is applied to a private attribute then all auto-generated methods will be private
too. 

The call-back style options such as C<builder>, C<trigger>, C<filter> are expected to share the privace mode of their
respective attribute:

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

Though if a callback option is defined with method name instead of C<Bool> I<True> then if method wit the same privacy
mode is not found then opposite mode would be tried before failing:

=begin code
    class Foo {
        has $.bar is mooish( :trigger<on_change> );
        has $!baz is mooish( :trigger<on_change> );
        has $!fubar is mooish( :lazy<set-fubar> );

        method !on_change ( $val ) { say "changed! ({$val})"; }
        method set-baz { $!baz = "new pvt" }
        method use-fubar { $!fubar }
    }

    $inst = Foo.new;
    $inst.bar = "new";  # changed! (new)
    $inst.set-baz;      # changed! (new pvt)
    $inst.use-fubar;    # Dies with "No such private method '!set-fubar' for invocant of type 'Foo'" message
=end code

=head2 User method's (callbacks) options

User defined (callback-type) methods receive additional named parameters (options) to help them understand their
context. For example, a class might have a couple of attributes for which it's ok to have same trigger method if only it
knows what attribute it is applied to:

=begin code
    class Foo {
        has $.foo is rw is mooish(:trigger('on_fubar'));
        has $.bar is rw is mooish(:trigger('on_fubar'));

        method on_fubar ( $value, *%opt ) {
            say "Triggered for {%opt<attribute>} with {$value}";
        }
    }

    my $inst = Foo.new;
    $inst.foo = "ABC";
    $inst.bar = "123";
=end code

    The expected output would be:

=begin code
    Triggered for $!foo with with ABC
    Triggered for $!bar with with 123
=end code

B<NOTE:> If a method doesn't care about named parameters it may only have positional arguments in its signature. This
doesn't work for pointy blocks where anonymous slurpy hash would be required:

=begin code
    class Foo {
        has $.bar is rw is mooish(:trigger(-> $, $val, *% {...})); 
    }
=end code

=head3 Options

=begin item
I<C<attribute>>

Full attribute name with twigil. Passed to all callbacks.
=end item

=begin item
I<C<builder>>

Only set to I<True> for C<filter> and C<trigger> methods when attribute value is generated by lazy builder. Otherwise no
this parameter is not passed to the method.
=end item

=begin item
I<C<old-value>>

Set for C<filter> only. See its description above.
=end item

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

# PvtMode enum defines what privacy mode is used when looking for an option method:
# force: makes the method always private
# never: makes it always public
# as-attr: makes is strictly same as attribute privacy
# auto: when options is defined with method name string then uses attribute mode first; and uses opposite if not
#       found. Always uses attribute mode if defined as Bool
enum PvtMode <pvmForce pvmNever pvmAsAttr pvmAuto>;

my %opt2prefix = clearer => 'clear', 
                 predicate => 'has',
                 builder => 'build',
                 trigger => 'trigger',
                 filter => 'filter',
                 composer => 'compose',
                 ;

my role AttrXMooishClassHOW { ... }

my role AttrXMooishAttributeHOW {
    has $.base-name = self.name.substr(2);
    has $.lazy is rw = False;
    has $.builder is rw = 'build-' ~ $!base-name;
    has $.clearer is rw = False;
    has $.predicate is rw = False;
    has $.trigger is rw = False;
    has $.filter is rw = False;
    has $.composer is rw = False;

    # This type is to coerce values into
    has $!coerce-type;
    # This type is to check (possibly – coerced) values against. The difference with coerce-type is that the latter
    # is a simple (kinda atomic) types like Int, Str, Array, Hash. Whereas check-type could be a subset. Though it
    # can't be a typed Array/Hash/etc.
    has $!check-type;
    has $!coerce-method;

    method !bool-str-meth-name( $opt, Str $prefix ) {
        $opt ~~ Bool ?? $prefix ~ '-' ~ $!base-name !! $opt;
    }

    method !opt2method( Str $oname ) {
        self!bool-str-meth-name( self."$oname"(), %opt2prefix{$oname} );
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
            clearer => my method { $attr.clear-attr( self.WHICH ) },
            predicate => my method { $attr.is-set( self.WHICH ) },
            ;

        for %helpers.keys -> $helper {
            next unless self."$helper"();
            my $helper-name = self!opt2method( $helper );

            X::Fatal.new( message => "Cannot install {$helper} {$helper-name}: method already defined").throw
                if type.^declares_method( $helper-name );

            my &m = %helpers{$helper};
            &m.set_name( $helper-name );
            #note "HELPER:", %helpers{$helper}.name;

            if $.has_accessor { # I.e. – public?
                type.^add_method( $helper-name, %helpers{$helper} );
            } else {
                type.^add_private_method( $helper-name, %helpers{$helper} );
            }
        }

        self.invoke-composer( type );

        $!coerce-type = $.auto_viv_container.WHAT;
        unless $!coerce-type === Any {
            #note ". attribute type is {$.type.^name} // {$.type.HOW.^name}";
            #note ". attribute container type is {$!coerce-type.^name} // {$!coerce-type.HOW.^name}";
            #note ". . {$!coerce-type.HOW.^roles(:!local).map( { $_.^shortname } )}" if $!coerce-type.HOW.^isa(Metamodel::ClassHOW);
            #note ". !coerce-type HOW is {$!coerce-type.HOW.^name} // is subset? ", $!coerce-type.HOW.^isa( Metamodel::SubsetHOW );
            #note ". . . ", $!coerce-type.^parents( :local ).WHO;
            #note "AV:", $.auto_viv_container.^find_method( 'of', no_fallback => 1 );
            if $!coerce-type.HOW.^isa( Metamodel::SubsetHOW ) {
                $!check-type = $!coerce-type; # Must check values against subset
                $!coerce-type = $!coerce-type.^refinee;
                #note ". final type: {$!coerce-type.^name}";
            }
            elsif $!coerce-type.HOW.^isa( Metamodel::DefiniteHOW ) {
                $!coerce-type = $!coerce-type.^base_type;
            }
            elsif $.auto_viv_container.WHAT.^find_method( 'of' ) && $.auto_viv_container.of.^isa( Any ) {
                #note ".... typed!";
                $!coerce-type = $!coerce-type.^parents( :local )[0];
                $!check-type = $!coerce-type; # Check values against base type.
                #note ".... >>> ", $!coerce-type.WHO;
            }
            #note ". setting the corce-method {$!coerce-type.^shortname}";
            $!coerce-method = ~$!coerce-type.WHO;
            #note "COERCE-METHOD is ", $!coerce-method;
        }

        #note "+++ done composing attribute {$.name}";
    }

    # force-default is true if attribute is set in .new( ) call
    method make-mooish ( Mu \instance, %attrinit ) {
        my $attr = self;
        my $obj-id = instance.WHICH;
        #note "Using obj ID:", $obj-id;

        return if so %attr-data{$obj-id}{$.name};

        #note ">>> MOOIFYING ", $.name;
        #note ">>> HAS INIT: ", %attrinit{$.base-name}:exists;

        my $from-init = %attrinit{$.base-name}:exists;
        my $default = $from-init ?? %attrinit{$.base-name} !! self.get_value( instance );
        my $initialized = $from-init;
        #note "DEFAULT IS:", $default // $default.WHAT;
        unless $initialized { # False means no constructor parameter for the attribute
            given $default {
                when Array | Hash { $initialized = so .elems; }
                default { $initialized = .defined }
            }
        }

        if $initialized {
            #note "=== Using initial value ({$initialized} // {$from-init}) ", $default;
            my @params;
            @params.append( {:constructor} ) if $from-init;
            #note "INIT STORE PARAMS: {@params}";
            self.store-with-cb( instance, $default, @params );
        }

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

    method store-with-cb ( Mu \instance, $value is rw, @params = () ) {
        ##note "INVOKING {$.name} FILTER WITH {@params.perl}";
        self.invoke-filter( instance, $value, @params );
        #note "STORING VALUE";
        self.store-value( instance.WHICH, $value );
        #note "INVOKING {$.name} TRIGGER WITH {@params.perl}";
        self.invoke-opt( instance, 'trigger', ( $value, |@params ), :strict ) if $.trigger;
    }

    method check-value ( $value ) {
        #note "CHECKING VALUE:", $value;
        my $operation = "assignment to attribute {$.name}";
        #note "VAL DEF:", $value.defined;
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
        elsif $!coerce-type ~~ Iterable {
            #note ". trying through append on iterable ", $!coerce-type.WHO;
            # For Array/Hash
            my $cv = $.auto_viv_container.clone;
            #note "Appending to ", $cv.WHAT;
            #note "Appending from ", $value.WHAT;
            given $cv {
                when Array {
                    $cv.append( |$value );
                }
                default {
                    # XXX Unfortunately, type checking for Hashes doesn't work as expected. Leave it alone for now!
                    #$cv.append( $value );
                }
            }
            #note ">>", $cv;
            #note ">>", $.auto_viv_container;
        }
        else {
            #note "VALUE: {$value.perl} // {$value.WHO}";
            #note "TYPE:", $!coerce-type;
            X::TypeCheck.new(
                :$operation,
                got => $value,
                expected => $.auto_viv_container.WHAT,
             ).throw unless $value ~~ $.auto_viv_container.WHAT;
        }
    }

    method coerce-value ( $val ) {
        #note "coerce-value";
        return $val unless $val.defined; # We only work with containers!
        return $val if $!coerce-type === Any;
        my $rval = $val;
        if my $meth = $val.^find_method( $!coerce-method, :no_fallback(1) ) {
            $rval = $val.&$meth();
            $rval.rethrow if $rval ~~ Failure;
            #note ". coerced rval: {$rval.perl}";
        }
        $rval
    }

    method store-value ( $obj-id, $value is copy ) {
        #note ". storing into {$.name}";
        $value = self.coerce-value( $value );
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

    method invoke-filter ( Mu \instance, $value is rw, @params = () ) {
        if $.filter {
            my $obj-id = instance.WHICH;
            my @invoke-params = $value, |@params;
            @invoke-params.push( 'old-value' => %attr-data{$obj-id}{$.name}<value> ) if self.is-set( $obj-id );
            $value = self.invoke-opt( instance, 'filter', @invoke-params, :strict );
        }
    }

    method invoke-opt ( Any \instance, Str $option, @params = (), :$strict = False, PvtMode :$private is copy = pvmAuto ) {
        my $opt-value = self."$option"();
        my \type = $.package;

        return unless so $opt-value;

        #note "&&& INVOKING {$option} on {$.name}";

        my @invoke-params = :attribute($.name), |@params;
        
        my $method;

        sub get-method( $name, Bool $public ) {
            $public ?? 
                    instance.^find_method( $name, :no_fallback(1) ) 
                    !!
                    type.^find_private_method( $name )
        }

        given $opt-value {
            when Str | Bool {
                if $opt-value ~~ Bool {
                    die "Bug encountered: boolean option $option doesn't have a prefix assigned"
                        unless %opt2prefix{$option};
                    $opt-value = "{%opt2prefix{$option}}-{$.base-name}";
                    # Bool-defined option must always have same privacy as attribute
                    $private = pvmAsAttr if $private == pvmAuto;
                }
                my $is-pub = $.has_accessor;
                given $private {
                    when pvmForce | pvmNever {
                        $method = get-method( $opt-value, $is-pub = $_ == pvmNever );
                    }
                    when pvmAsAttr {
                        $method = get-method( $opt-value, $.has_accessor );
                    }
                    when pvmAuto {
                        $method = get-method( $opt-value, $.has_accessor ) // get-method( $opt-value, !$.has_accessor );
                    }
                }
                #note "&&& ON INVOKING: found method ", $method.defined ;
                unless so $method {
                    # If no method found by name die if strict is on
                    #note "No method found for $option";
                    return unless $strict;
                    X::Method::NotFound.new(
                        method => $opt-value,
                        private =>!$is-pub,
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

        #note "INVOKING {$method ~~ Code ?? $method.name !! $method} with ", @invoke-params.Capture;
        instance.$method(|(@invoke-params.Capture));
    }

    method build-attr ( Any \instance ) {
        my $obj-id = instance.WHICH;
        my $publicity = $.has_accessor ?? "public" !! "private";
        #note "&&& KINDA BUILDING FOR $publicity {$.name} on $obj-id (is-set:{self.is-set($obj-id)})";
        unless self.is-set( $obj-id ) {
            #note "&&& Calling builder {$!builder}";
            my $val = self.invoke-opt( instance, 'builder', :strict );
            self.store-with-cb( instance, $val, [ :builder ] );
            #note "Set ATTR";
        }
    }

    method invoke-composer ( Mu \type ) {
        return unless $!composer;
        #note "My type for composer: ", $.package;
        my $comp-name = self!opt2method( 'composer' );
        #note "Looking for method $comp-name";
        my $composer = type.^find_private_method( $comp-name );
        X::Method::NotFound.new(
            method    => $comp-name,
            private  => True,
            typename => type.WHO,
        ).throw unless $composer;
        type.&$composer();
    }
}

my role AttrXMooishClassHOW {

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

        my $has-build = type.^declares_method( 'BUILD' );
        %wrap-methods<BUILD> = my submethod (*%attrinit) {
            #note "&&& CUSTOM BUILD on {self.WHO} by {type.WHO}";
            # Don't pass initial attributes if wrapping user's BUILD - i.e. we don't initialize from constructor
            type.^on_create( self, $has-build ?? {} !! %attrinit );
            when !$has-build {
                # We would have to init all attributes from attrinit. Even those without the trait.
                my $base-name;
                for type.^attributes( :local(1) ).grep( {
                    $_ !~~ AttrXMooishAttributeHOW
                    && .has_accessor 
                    && (%attrinit{$base-name = .name.substr(2)}:exists)
                } ) -> $lattr {
                    #note "--- INIT PUB ATTR $base-name";
                    #note "WHO:", $lattr.WHO;
                    my $val = %attrinit{$base-name};
                    $lattr.set_value( self, $val );
                }
            }
            nextsame;
        }

        for %wrap-methods.keys -> $method-name {
            my $orig-method = type.^declares_method( $method-name );
            my $my-method = %wrap-methods{$method-name};
            $my-method.set_name( $method-name );
            if $orig-method {
                #note "&&& WRAPPING $method-name";
                type.^find_method($method-name, :no_fallback(1)).wrap( $my-method );
            }
            else {
                #note "&&& ADDING $method-name";
                self.add_method( type, $method-name, $my-method );
            }
        }

        type.^setup_finalization;
        #type.^compose_repr;
        #note "+++ done installing stagers";
    }

    method create_BUILDPLAN ( Mu \type ) {
        #note "+++ PREPARE {type.WHO}";
        self.install-stagers( type );
        callsame;
        #note "+++ done create_BUILDPLAN";
    }


    method on_create ( Mu \type, Mu \instance, %attrinit ) {
        #note "ON CREATE";

        my @lazyAttrs = type.^attributes( :local(1) ).grep( AttrXMooishAttributeHOW );

        for @lazyAttrs -> $attr {
            #note "Found lazy attr {$attr.name} // {$attr.HOW}";
            $attr.make-mooish( instance, %attrinit );
        }
    }

    method slots-used {
        #note Dump( $(%attr-data) );
        %attr-data.keys.elems;
    }
}

my role AttrXMooishRoleHOW {
    method specialize(Mu \r, Mu:U \obj, *@pos_args, *%named_args) {
        #note "*** Specializing role on {obj.WHO}";
        #note "CLASS HAS THE ROLE:", obj.HOW ~~ AttrXMooishClassHOW;
        obj.HOW does AttrXMooishClassHOW unless obj.HOW ~~ AttrXMooishClassHOW;
        nextsame;
    }
}

multi trait_mod:<is>( Attribute:D $attr, :$mooish! ) is export {
    $attr does AttrXMooishAttributeHOW;
    #note "Applying for {$attr.name} to ", $*PACKAGE.WHO, " // ", $*PACKAGE.HOW;
    #$*PACKAGE.HOW does AttrXMooishClassHOW unless $*PACKAGE.HOW ~~ AttrXMooishClassHOW;
    given $*PACKAGE.HOW {
        when Metamodel::ParametricRoleHOW {
            $_ does AttrXMooishRoleHOW unless $_ ~~ AttrXMooishRoleHOW;
        }
        default {
            $_ does AttrXMooishClassHOW unless $_ ~~ AttrXMooishClassHOW;
        }
    }

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
                    when 'trigger' | 'filter' | 'composer' {
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
