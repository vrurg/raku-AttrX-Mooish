unit module AttrX::Mooish:ver<0.7.5>:auth<zef:vrurg>:api<0.7.0>;
#use Data::Dump;
use nqp;

CHECK {
    die "Rakudo of at least v2019.11 required to run this version of " ~ ::?PACKAGE.^name
        unless $*RAKU.compiler.version >= v2019.11;
}

class X::Fatal is Exception {
    #has Str $.message is rw;
}

class X::TypeCheck::MooishOption is X::TypeCheck {
    method expectedn {
        "Str or Callable";
    }
}

class X::NotAllowed is X::Fatal {
    has Str:D $.op is required;
    has Str $.cause;
    method message {
        "Operation '$!op' is not allowed at this time" ~ ($!cause ?? ": $!cause" !! "")
    }
}

my class AttrProxy is Proxy {
    has $.val is rw;
    has Bool $.is-set is rw is default(False);
    has Promise $!built-promise;
    has Bool $.mooished is rw is default(False);

    method clear {
        $!val = Nil;
        $!is-set = Nil;
        $!built-promise = Nil;
    }

    method build-acquire {
        return False if $!is-set;
        my $bp = $!built-promise;
        if !$bp.defined && cas($!built-promise, $bp, Promise.new) === $bp {
            return True;
        }
        await $!built-promise;
        False
    }

    method build-release {
        $!built-promise.keep(True);
    }

    method is-building {
        ? (nqp::defined($!built-promise) && $!built-promise.status ~~ Planned);
    }

    method assign-val( Mu $value is raw ) {
        nqp::p6assign($!val, $value);
        $!is-set = True;
    }
    method bind-val( Mu $value is raw ) {
        nqp::bindattr(self, AttrProxy, '$!val', $value);
        # $!val := $value;
        $!is-set = True;
    }
}

# PvtMode enum defines what privacy mode is used when looking for an option method:
# force: makes the method always private
# never: makes it always public
# as-attr: makes is strictly same as attribute privacy
# auto: when options is defined with method name string then uses attribute mode first; and uses opposite if not
#       found. Always uses attribute mode if defined as Bool
enum PvtMode <pvmForce pvmNever pvmAsAttr pvmAuto>;

role AttrXMooishClassHOW { ... }

role AttrXMooishHelper {
    method setup-helpers ( Mu \type, $attr ) is hidden-from-backtrace {
        my sub get-attr-obj( Mu \obj, $attr ) is raw is hidden-from-backtrace {
            $attr.package.HOW ~~ Metamodel::GenericHOW
                ?? (
                    ( try { obj.^get_attribute_for_usage($attr.name) } )
                    || obj.^attributes.grep({ $_.name eq $attr.name }).first
                )
                !! $attr;
        }
        my %helpers =
            :clearer( my method () is hidden-from-backtrace {
                # Can't use $attr to call bind-proxy upon if the original attribute belongs to a role. In this case its
                # .package is not defined.
                # Metamodel::GenericHOW only happens for role attributes
                my $attr-obj = get-attr-obj(self, $attr);
                my $attr-var := $attr-obj.bind-proxy( self, nqp::getattr(self, $attr-obj.package, $attr.name).VAR );
                $attr-obj.clear-attr( self );
                $attr-var.mooished = True;
             } ),
            :predicate( my method   { get-attr-obj(self, $attr).is-set( self ) } ),
            ;

        my @aliases = $attr.base-name, |$attr.init-args;

        for %helpers.keys -> $helper {
            next unless $attr."$helper"(); # Don't generate if attribute isn't set
            for @aliases -> $base-name {
                my $helper-name = $attr.opt2method( $helper, :$base-name  );

                X::Fatal.new( message => "Cannot install {$helper} {$helper-name}: method already defined").throw
                    if type.^declares_method( $helper-name );

                my $m = %helpers{$helper};
                $m.set_name( $helper-name );

                if $attr.has_accessor { # I.e. – public?
                    type.^add_method( $helper-name, $m );
                } else {
                    type.^add_private_method( $helper-name, $m );
                }
            }
        }
    }
}

my sub typecheck-attr-value ( $attr is raw, Mu $value is raw ) is raw is hidden-from-backtrace {
    my $rc;
    given $attr.name.substr(0,1) {      # Take sigil from attribute name
        when '$' {
            # Do it via nqp because I didn't find any syntax-based way to properly clone a Scalar container
            # as such.
            my $v := nqp::create(Scalar);
            nqp::bindattr(
                $v, Scalar, '$!descriptor',
                nqp::getattr(nqp::decont($attr), Attribute, '$!container_descriptor')
            );
            # Workaround for a bug when optimization could fail if $value is Nil
            $rc := nqp::if(nqp::eqaddr($value, Nil), ($v = Nil), ($v = $value));
        }
        when '@' {
            my @a := $attr.auto_viv_container.clone;
            $rc := @a = |$value;
        }
        when '%' {
            my %h := $attr.auto_viv_container.clone;
            $rc := %h = $value;
        }
        when '&' {
            my &m := nqp::clone($attr.auto_viv_container.VAR);
            $rc := &m = $value;
        }
        default {
            die "AttrX::Mooish can't handle «$_» sigil";
        }
    }
    $rc
}

role AttrXMooishAttributeHOW {
    has $.base-name = self.name.substr(2);
    has $!sigil = self.name.substr( 0, 1 );
    has $!always-bind = False;
    has $.lazy is rw = False;
    has $.builder is rw = 'build-' ~ $!base-name;
    has $.clearer is rw = False;
    has $.predicate is rw = False;
    has $.trigger is rw = False;
    has $.filter is rw = False;
    has $.composer is rw = False;
    has $.no-init is rw = False;
    has @.init-args;

    my %opt2prefix = clearer => 'clear',
                     predicate => 'has',
                     builder => 'build',
                     trigger => 'trigger',
                     filter => 'filter',
                     composer => 'compose',
                     ;

    method !bool-str-meth-name( $opt, Str $prefix, Str :$base-name? ) is hidden-from-backtrace {
        $opt ~~ Bool ?? $prefix ~ '-' ~ ( $base-name // $!base-name ) !! $opt;
    }

    method opt2method( Str $oname, Str :$base-name? ) is hidden-from-backtrace {
        self!bool-str-meth-name( self."$oname"(), %opt2prefix{$oname}, :$base-name );
    }

    method compose ( Mu \type, :$compiler_services ) is hidden-from-backtrace {
        return if try nqp::getattr_i(self, Attribute, '$!composed');

        $!always-bind = $!filter || $!trigger;

        unless type.HOW ~~ AttrXMooishClassHOW {
            type.HOW does AttrXMooishClassHOW;
        }

        for @!init-args -> $alias {
            my $meth := $compiler_services.generate_accessor(
                $alias, nqp::decont(type), $.name, nqp::decont( $.type ), $.rw ?? 1 !! 0
            );
            type.^add_method( $alias, $meth );
        }

        callsame;

        self.invoke-composer( type );
    }

    method make-mooish ( Mu \instance, %attrinit ) is hidden-from-backtrace {
        my $attr = self;
        my Mu $attr-var := nqp::getattr(nqp::decont(instance), $.package, $.name).VAR;

        return if nqp::istype($attr-var, AttrProxy);

        my $init-key = $.no-init ?? Nil !! ($!base-name, |@!init-args).grep( { %attrinit{$_}:exists } ).head;
        my $initialized = ? $init-key;
        my $default = $initialized ?? %attrinit{$init-key} !! self.get_value( instance );
        unless $initialized { # False means no constructor parameter for the attribute
            given $default {
                when Array | Hash { $initialized = so .elems; }
                default { $initialized = nqp::isconcrete(nqp::decont($_)) }
            }
        }

        $attr-var := self.bind-proxy( instance, $attr-var );

        if $initialized {
            my @params;
            @params.append( {:constructor} ) if $init-key;
            self.store-with-cb( instance, $attr-var, $default, @params );
        }

        $attr-var.mooished = True;
    }

    method bind-proxy ( Mu \instance, Mu $attr-var is raw ) is raw is hidden-from-backtrace {
        my $attr = self;
        return $attr-var if nqp::istype($attr-var, AttrProxy);

        my $proxy;
        nqp::bindattr(nqp::decont(instance), $.package, $.name,
            $proxy := AttrProxy.new(
                FETCH => -> $ {
                    my Mu $attr-var := $proxy.VAR;
                    my Mu $val;

                    if $!sigil eq '$' | '&' {
                        $val := nqp::clone(self.auto_viv_container.VAR);
                    }
                    else {
                        $val := self.auto_viv_container.clone;
                    }

                    if nqp::istype($attr-var, AttrProxy) && $attr-var.mooished {
                        if ?$!lazy && $attr-var.build-acquire {
                            LEAVE $attr-var.build-release;
                            self.build-attr( instance, $attr-var );
                        }
                        $val := $attr-var.val if $attr-var.is-set;
                        # Once read and built, mooishing is not needed unless filter or trigger are set; and until
                        # clearer is called.
                        self.unbind-proxy( instance, $attr-var, $val );
                    }
                    $val
                },
                STORE => sub ($, Mu $value is raw) is hidden-from-backtrace {
                    self.store-with-cb( instance, $proxy.VAR, $value );
                }
            )
        );
        $proxy.VAR
    }

    method unbind-proxy ( Mu \instance, $attr-var is raw, Mu $val is raw ) is hidden-from-backtrace {
        unless $!always-bind or $attr-var !~~ AttrProxy {
            nqp::bindattr( nqp::decont(instance), $.package, $.name, $val );
        }
    }

    method store-with-cb ( Mu \instance, $attr-var is raw, Mu $value is raw, @params = [] ) is hidden-from-backtrace {
        @params.append: ( :old-value( nqp::clone($attr-var.val) ) ) if $attr-var.is-set;
        my Mu $filtered := $!filter ?? self.invoke-filter( instance, $attr-var, $value, @params ) !! $value;
        self.store-value( instance, $attr-var, $filtered );
        self.invoke-opt( instance, 'trigger', ( $filtered, |@params ), :strict ) if $!trigger;
    }

    # store-value would return the value stored.
    method store-value ( Mu \instance, $attr-var is raw, Mu $value is raw ) is hidden-from-backtrace {
        if $attr-var.is-set {
                given $!sigil {
                    when '$' | '&' {
                            $attr-var.assign-val( $value );
                    }
                    when '@' | '%' {
                        $attr-var.val.STORE(nqp::decont($value));
                    }
                    default {
                        die "AttrX::Mooish can't handle «$_» sigil";
                    }
                }
        }
        else {
            $attr-var.bind-val( typecheck-attr-value( self, $value ) );
        }

        self.unbind-proxy( instance, $attr-var, $attr-var.val );
    }

    method is-set ( Mu \obj ) is hidden-from-backtrace {
        my $attr-var := nqp::getattr(nqp::decont(obj), $.package, $.name).VAR;
        !nqp::istype($attr-var, AttrProxy) || $attr-var.is-set
    }

    method clear-attr ( Mu \obj ) is hidden-from-backtrace {
        my $attr-var := nqp::getattr(nqp::decont(obj), $.package, $.name).VAR;
        X::NotAllowed.new(:op('clear'), :cause("attribute " ~ $.name ~ " is still building")).throw
            if $attr-var.is-building;
        $attr-var.clear if nqp::istype($attr-var, AttrProxy);
    }

    method invoke-filter ( Mu \instance, $attr-var is raw, Mu $value is raw, @params = [] ) is raw is hidden-from-backtrace {
        $!filter
            ?? self.invoke-opt( instance, 'filter', ($value, |@params), :strict )
            !! $value
    }

    method invoke-opt ( Any \instance,
                        Str $option,
                        @params = (),
                        :$strict = False,
                        PvtMode :$private is copy = pvmAuto ) is raw is hidden-from-backtrace
    {
        my $opt-value = self."$option"();
        my \type = $.package;

        return unless so $opt-value;

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
                    $opt-value = "{%opt2prefix{$option}}-{$!base-name}";
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
                unless so $method {
                    # If no method found by name die if strict is on
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

        instance.$method(|(@invoke-params.Capture))
    }

    method build-attr ( Mu \instance, $attr-var is raw ) is hidden-from-backtrace {
        my Mu $val := self.invoke-opt( instance, 'builder', :strict );
        self.store-with-cb( instance, $attr-var, $val, [ :builder ] );
    }

    method invoke-composer ( Mu \type ) is hidden-from-backtrace {
        return unless $!composer;
        my $comp-name = self.opt2method( 'composer' );
        my &composer = type.^find_private_method( $comp-name );
        X::Method::NotFound.new(
            method    => $comp-name,
            private  => True,
            typename => type.WHO,
        ).throw unless &composer;
        type.&composer();
    }
}

role AttrXMooishClassHOW does AttrXMooishHelper {
    has %!init-arg-cache;

    method compose ( Mu \type, :$compiler_services ) is hidden-from-backtrace {
        for type.^attributes.grep( AttrXMooishAttributeHOW ) -> $attr {
            self.setup-helpers( type, $attr );
        }
        nextsame;
    }

    method install-stagers ( Mu \type ) is hidden-from-backtrace {
        my %wrap-methods;
        my $how = self;

        my $has-build = type.^declares_method( 'BUILD' );
        my $iarg-cache := %!init-arg-cache;
        %wrap-methods<BUILD> = my submethod (*%attrinit) {
            # Don't pass initial attributes if wrapping user's BUILD - i.e. we don't initialize from constructor
            type.^on_create( self, $has-build ?? {} !! %attrinit );

            when !$has-build {
                # We would have to init all non-mooished attributes from attrinit.
                my $base-name;
                for type.^attributes( :local(1) ).grep( {
                    $_ !~~ AttrXMooishAttributeHOW
                    && .has_accessor
                    && (%attrinit{$base-name = .name.substr(2)}:exists)
                } ) -> $lattr {
                    $lattr.set_value( self, typecheck-attr-value( $lattr, %attrinit{$base-name} ) );
                }
            }
            nextsame;
        }

        for %wrap-methods.keys -> $method-name {
            my $orig-method = type.^declares_method( $method-name );
            my $my-method = %wrap-methods{$method-name};
            $my-method.set_name( $method-name );
            if $orig-method {
                type.^find_method($method-name, :no_fallback(1)).wrap( $my-method );
            }
            else {
                self.add_method( type, $method-name, $my-method );
            }
        }

        type.^setup_finalization;
    }

    method create_BUILDPLAN ( Mu \type ) is hidden-from-backtrace {
        self.install-stagers( type );
        callsame;
    }

    my $init-lock = Lock.new;
    method on_create ( Mu \type, Mu \instance, %attrinit ) is hidden-from-backtrace {
        my @lazyAttrs = type.^attributes( :local(1) ).grep( AttrXMooishAttributeHOW );

        $init-lock.protect: {
            for @lazyAttrs -> $attr {
                next unless %!init-arg-cache{ $attr.name }:exists;
                %!init-arg-cache{ $attr.name } = $attr if $attr.init-args.elems > 0;
            }
        }

        for @lazyAttrs -> $attr {
            $attr.make-mooish( instance, %attrinit );
        }
    }
}

role AttrXMooishRoleHOW does AttrXMooishHelper {
    method compose (Mu \type, :$compiler_services ) is hidden-from-backtrace {
        for type.^attributes.grep( AttrXMooishAttributeHOW ) -> $attr {
            self.setup-helpers( type, $attr );
        }
        nextsame
    }

    method specialize(Mu \r, Mu:U \obj, *@pos_args, *%named_args) is hidden-from-backtrace {
        obj.HOW does AttrXMooishClassHOW unless obj.HOW ~~ AttrXMooishClassHOW;
        nextsame;
    }
}

multi trait_mod:<is>( Attribute:D $attr, :$mooish! ) is export {
    $attr does AttrXMooishAttributeHOW;
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
                    when 'no-init' {
                        $attr.no-init = ? $option.value;
                    }
                    when 'init-arg' | 'alias' | 'init-args' | 'aliases' {
                        given $option{$_} {
                            X::Fatal.new( message => "Unsupported {$_} type of {.WHAT} for attribute {$attr.name}; can only be Str or Positional" ).throw
                                unless $_ ~~ Str | Positional;
                            $attr.init-args.append: $_<>;
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

our sub META6 {
	use META6;
    name           => 'AttrX::Mooish',
    description    => 'Extending attribute functionality with ideas from Moo/Moose',
    version        => AttrX::Mooish.^ver,
	auth		   => AttrX::Mooish.^auth,
	api			   => AttrX::Mooish.^api,
    perl-version   => Version.new('6.*'),
    raku-version   => Version.new('6.*'),
    depends        => [],
    test-depends   => <Test Test::META Test::When>,
	#build-depends  => <Pod::To::Markdown>,
    tags           => <AttrX Moo Moose Mooish attribute mooish trait>,
    authors        => ['Vadim Belman <vrurg@cpan.org>'],
    source-url     => 'git://github.com/vrurg/raku-AttrX-Mooish.git',
    support        => META6::Support.new(
        source          => 'https://github.com/vrurg/raku-AttrX-Mooish.git',
    ),
    provides => {
        'AttrX::Mooish' => 'lib/AttrX/Mooish.rakumod',
    },
    license        => 'Artistic-2.0',
    production     => True,
}

# Copyright (c) 2018, Vadim Belman <vrurg@cpan.org>
#
# Check the LICENSE file for the license

# vim: tw=120 ft=perl6
