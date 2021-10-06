unit module AttrX::Mooish:ver<0.7.4>:auth<zef:vrurg>:api<0.7.0>;
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
            # note "ACQUIRE SUCCESS";
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

    method assign-val( $value is raw ) {
        nqp::p6assign($!val, $value);
        $!is-set = True;
    }
    method bind-val( $value is raw ) {
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
        # note "SETUP HELPERS ON ", type.^name, " // ", type.HOW.^name;
        # note " .. for attr ", $attr.name;
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
            #note "op2method for helper $helper";
            for @aliases -> $base-name {
                my $helper-name = $attr.opt2method( $helper, :$base-name  );

                X::Fatal.new( message => "Cannot install {$helper} {$helper-name}: method already defined").throw
                    if type.^declares_method( $helper-name );

                my $m = %helpers{$helper};
                $m.set_name( $helper-name );
                #note "Installing helper $helper $helper-name on {type.^name} // {$m.WHICH}";
                #note "HELPER:", %helpers{$helper}.name, " // ", $m.^can("CALL-ME"), " // ", $m.^name;

                if $attr.has_accessor { # I.e. – public?
                    #note ". Installing public $helper-name";
                    type.^add_method( $helper-name, $m );
                } else {
                    #note "! Installing private $helper-name";
                    type.^add_private_method( $helper-name, $m );
                }
            }
        }
    }
}

my sub typecheck-attr-value ( $attr is raw, $value ) is raw is hidden-from-backtrace {
    my $rc;
    given $attr.name.substr(0,1) {      # Take sigil from attribute name
        when '$' {
            # Do it via nqp because I didn't find any syntax-based way to properly clone a Scalar container
            # as such.
            my $v := nqp::create(Scalar);
            nqp::bindattr($v, Scalar, '$!descriptor',
                nqp::getattr(nqp::decont($attr), Attribute, '$!container_descriptor')
            );
            # note "SCALAR OF ", $v.VAR.of;
            $rc := $v = $value;
        }
        when '@' {
            #note "ASSIGN TO POSITIONAL";
            my @a := $attr.auto_viv_container.clone;
            #note $value.perl;
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
    # note "=== RC: ", $rc.VAR.^name, " // ", $rc.VAR.of;
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
        #note "bool-str-meth-name: ", $prefix;
        $opt ~~ Bool ?? $prefix ~ '-' ~ ( $base-name // $!base-name ) !! $opt;
    }

    method opt2method( Str $oname, Str :$base-name? ) is hidden-from-backtrace {
        #note "%opt2prefix: ", %opt2prefix;
        #note "option name in opt2method: $oname // ", %opt2prefix{$oname};
        self!bool-str-meth-name( self."$oname"(), %opt2prefix{$oname}, :$base-name );
    }

    method compose ( Mu \type, :$compiler_services ) is hidden-from-backtrace {
        # note "+++ composing {$.name} on {type.^name} {type.HOW}, was composed? ", $composed;
        # $!composed is a recent addition on Attribute object.
        return if try nqp::getattr_i(self, Attribute, '$!composed');

        # note "ATTR PACKAGE:", $.package.^name;

        $!always-bind = $!filter || $!trigger;

        unless type.HOW ~~ AttrXMooishClassHOW {
            #note "Installing AttrXMooishClassHOW on {type.WHICH}";
            type.HOW does AttrXMooishClassHOW;
        }

        for @!init-args -> $alias {
            # note "GEN ACCESSOR $alias for {$.name} on {type.^name}";
            my $meth := $compiler_services.generate_accessor(
                $alias, nqp::decont(type), $.name, nqp::decont( $.type ), $.rw ?? 1 !! 0
            );
            type.^add_method( $alias, $meth );
        }

        callsame;

        self.invoke-composer( type );

        #note "+++ done composing attribute {$.name}";
    }

    method make-mooish ( Mu \instance, %attrinit ) is hidden-from-backtrace {
        my $attr = self;
        my Mu $attr-var := nqp::getattr(nqp::decont(instance), $.package, $.name).VAR;

        return if nqp::istype($attr-var, AttrProxy);

        # note ">>> HAS INIT: ", %attrinit;

        my $init-key = $.no-init ?? Nil !! ($!base-name, |@!init-args).grep( { %attrinit{$_}:exists } ).head;
        # note "=== Taking $!base-name from init? ", ? $init-key;
        my $initialized = ? $init-key;
        my $default = $initialized ?? %attrinit{$init-key} !! self.get_value( instance );
        # note "DEFAULT IS:", $default // $default.WHAT;
        unless $initialized { # False means no constructor parameter for the attribute
            # note ". No $.name constructor parameter on $obj-id, checking default {$default // '(Nil)'}";
            given $default {
                when Array | Hash { $initialized = so .elems; }
                default { $initialized = nqp::isconcrete(nqp::decont($_)) }
            }
        }

        # note "ATTR-VAR BEFORE BIND: ", $attr-var.^name;
        $attr-var := self.bind-proxy( instance, $attr-var );
        # note "ATTR-VAR AFTER BIND: ", $attr-var.^name;

        if $initialized {
            # note "=== Using initial value (initialized:{$initialized}) ", $default;
            my @params;
            @params.append( {:constructor} ) if $init-key;
            # note "INIT STORE PARAMS: {@params}";
            self.store-with-cb( instance, $attr-var, $default, @params );
        }

        # note "Setting mooished";
        $attr-var.mooished = True;
        # note "<<< DONE MOOIFYING ", $.name;
    }

    method bind-proxy ( Mu \instance, Mu $attr-var is raw ) is raw is hidden-from-backtrace {
        my $attr = self;
        return $attr-var if nqp::istype($attr-var, AttrProxy);

        # note "++++ BINDING PROXY TO ", $.name;

        my $proxy;
        nqp::bindattr(nqp::decont(instance), $.package, $.name,
            $proxy := AttrProxy.new(
                FETCH => -> $ {
                    # note "FETCHING";
                    my Mu $attr-var := $proxy.VAR;
                    my $val;
                    # note "ATTR<{$.name}> SIGIL: ", $!sigil, ", attr-var:", $attr-var.^name, " prox: ", $proxy.VAR.^name;
                    # note "SELF:", self.^name, ", auto viv: ", nqp::getattr(self, Attribute, '$!auto_viv_container').^name, ", generic? ", self.auto_viv_container.HOW.archetypes.generic;
                    if $!sigil eq '$' | '&' {
                        $val := nqp::clone(self.auto_viv_container.VAR);
                    }
                    else {
                        $val := self.auto_viv_container.clone;
                    }
                    # note "IS MOOISHED? ", ? nqp::istype($attr-var, AttrProxy) && $attr-var.mooished;
                    if nqp::istype($attr-var, AttrProxy) && $attr-var.mooished {
                        # note "FETCH of {$attr.name}, lazy? ", ?$!lazy, ", set? ", $attr-var.is-set;
                        if ?$!lazy && $attr-var.build-acquire {
                            LEAVE $attr-var.build-release;
                            # note "BUILDING {$attr.name} for {instance.WHICH} attr var: ", $attr-var.^name, "|", nqp::objectid($attr-var);
                            self.build-attr( instance, $attr-var );
                        }
                        $val := $attr-var.val if $attr-var.is-set;
                        # note "Fetched value for {$.name}: ", $val.VAR.^name, " // ", $val.perl, "; attr was set? ", $attr-var.is-set;
                        # Once read and built, mooishing is not needed unless filter or trigger are set; and until
                        # clearer is called.
                        self.unbind-proxy( instance, $attr-var, $val );
                    }
                    $val
                },
                STORE => sub ($, $value is copy) is hidden-from-backtrace {
                    self.store-with-cb( instance, $proxy.VAR, $value );
                }
            )
        );
        $proxy.VAR
    }

    method unbind-proxy ( Mu \instance, $attr-var is raw, $val is raw ) is hidden-from-backtrace {
        unless $!always-bind or $attr-var !~~ AttrProxy {
            # note "---- UNBINDING ATTR {$.name} FROM {$attr-var.^name} INTO VALUE ({$val.^name}";
            nqp::bindattr( nqp::decont(instance), $.package, $.name, $val );
        }
    }

    method store-with-cb ( Mu \instance, $attr-var is raw, $value is rw, @params = [] ) is hidden-from-backtrace {
        @params.append: ( :old-value( nqp::clone($attr-var.val) ) ) if $attr-var.is-set;
        # note "INVOKING {$.name} FILTER WITH {@params.perl}";
        self.invoke-filter( instance, $attr-var, $value, @params ) if $!filter;
        # note "STORING VALUE: ($value) on ", ;
        self.store-value( instance, $attr-var, $value );
        # note "INVOKING {$.name} TRIGGER WITH {@params.perl}";
        self.invoke-opt( instance, 'trigger', ( $value, |@params ), :strict ) if $!trigger;
    }

    # store-value would return the value stored.
    method store-value ( Mu \instance, $attr-var is raw, $value is copy ) is hidden-from-backtrace {
        # note ". storing into {$.name} // ";
        # note "store-value($value) on attr({$.name}) of ", $attr-var.^name;

        if $attr-var.is-set {
                # note " . was set";
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
            # note " . binding new value";
            $attr-var.bind-val( typecheck-attr-value( self, $value ) );
            # note " . -> ", $attr-var.val;
        }

        self.unbind-proxy( instance, $attr-var, $attr-var.val );
    }

    method is-set ( Mu \obj ) is hidden-from-backtrace {
        my $attr-var := nqp::getattr(nqp::decont(obj), $.package, $.name).VAR;
        # note ". IS-SET on {$.name} of {$attr-var.^name}: ", (nqp::istype($attr-var, AttrProxy) ?? $attr-var.is-set !! "not proxy");
        !nqp::istype($attr-var, AttrProxy) || $attr-var.is-set
    }

    method clear-attr ( Mu \obj ) is hidden-from-backtrace {
        my $attr-var := nqp::getattr(nqp::decont(obj), $.package, $.name).VAR;
        X::NotAllowed.new(:op('clear'), :cause("attribute " ~ $.name ~ " is still building")).throw
            if $attr-var.is-building;
        # note "Clearing {$.name} on ", $attr-var.^name;
        $attr-var.clear if nqp::istype($attr-var, AttrProxy);
    }

    method invoke-filter ( Mu \instance, $attr-var is raw, $value is rw, @params = [] ) is hidden-from-backtrace {
        $value = self.invoke-opt( instance, 'filter', ($value, |@params), :strict ) if $!filter
    }

    method invoke-opt (
                Any \instance, Str $option, @params = (), :$strict = False, PvtMode :$private is copy = pvmAuto
            ) is hidden-from-backtrace {
        my $opt-value = self."$option"();
        my \type = $.package;

        return unless so $opt-value;

        # note "&&& INVOKING {$option} on {$.name}";

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

    method build-attr ( Any \instance, $attr-var is raw ) is hidden-from-backtrace {
        # my $publicity = $.has_accessor ?? "public" !! "private";
        # note "&&& KINDA BUILDING FOR $publicity {$.name} on {$attr-var.^name} (is-set:{$attr-var.is-set})";
        my $val = self.invoke-opt( instance, 'builder', :strict );
        # note "Set ATTR to ({$val})";
        self.store-with-cb( instance, $attr-var, $val, [ :builder ] );
    }

    method invoke-composer ( Mu \type ) is hidden-from-backtrace {
        return unless $!composer;
        #note "My type for composer: ", $.package;
        my $comp-name = self.opt2method( 'composer' );
        # note "Looking for method $comp-name";
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
        # note "+++ done composing {type.^name}";
        nextsame;
    }

    method install-stagers ( Mu \type ) is hidden-from-backtrace {
        # note "+++ INSTALLING STAGERS {type.WHO} {type.HOW}";
        my %wrap-methods;
        my $how = self;

        my $has-build = type.^declares_method( 'BUILD' );
        my $iarg-cache := %!init-arg-cache;
        %wrap-methods<BUILD> = my submethod (*%attrinit) {
            # note "&&& CUSTOM BUILD on {self.WHO} by {type.WHO} // has-build:{$has-build}";
            # Don't pass initial attributes if wrapping user's BUILD - i.e. we don't initialize from constructor
            # note "BUILD ON ", self.WHICH;
            type.^on_create( self, $has-build ?? {} !! %attrinit );

            when !$has-build {
                # We would have to init all non-mooished attributes from attrinit.
                my $base-name;
                # note "ATTRINIT: ", %attrinit;
                for type.^attributes( :local(1) ).grep( {
                    $_ !~~ AttrXMooishAttributeHOW
                    && .has_accessor
                    && (%attrinit{$base-name = .name.substr(2)}:exists)
                } ) -> $lattr {
                    # note "--- INIT PUB ATTR $base-name // ", $lattr.^name;
                    #note "WHO:", $lattr.WHO;
                    # my $val = %attrinit{$base-name};
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
                # note "&&& WRAPPING $method-name";
                type.^find_method($method-name, :no_fallback(1)).wrap( $my-method );
            }
            else {
                # note "&&& ADDING $method-name on {type.^name}";
                self.add_method( type, $method-name, $my-method );
            }
        }

        type.^setup_finalization;
        #type.^compose_repr;
        #note "+++ done installing stagers";
    }

    method create_BUILDPLAN ( Mu \type ) is hidden-from-backtrace {
        #note "+++ PREPARE {type.WHO}";
        self.install-stagers( type );
        callsame;
        #note "+++ done create_BUILDPLAN";
    }

    method on_create ( Mu \type, Mu \instance, %attrinit ) is hidden-from-backtrace {
        # note "ON CREATE, self: ", self.WHICH;

        state $init-lock = Lock.new;

        my @lazyAttrs = type.^attributes( :local(1) ).grep( AttrXMooishAttributeHOW );

        $init-lock.protect: {
            for @lazyAttrs -> $attr {
                # note "Found lazy attr {$attr.name} // {$attr.HOW} // ", $attr.init-args, " --> ", $attr.init-args.elems;
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
        # note "COMPOSING ROLE ", type.^name, " // ", type.HOW.^name, " // ", ? $compiler_services;
        for type.^attributes.grep( AttrXMooishAttributeHOW ) -> $attr {
            self.setup-helpers( type, $attr );
        }
        # note "+++ done composing {type.^name}";
        nextsame
    }

    method specialize(Mu \r, Mu:U \obj, *@pos_args, *%named_args) is hidden-from-backtrace {
        # note "*** Specializing role {r.^name} on {obj.WHO}";
        #note "CLASS HAS THE ROLE:", obj.HOW ~~ AttrXMooishClassHOW;
        obj.HOW does AttrXMooishClassHOW unless obj.HOW ~~ AttrXMooishClassHOW;
        #note "*** Done specializing";
        nextsame;
    }
}

multi trait_mod:<is>( Attribute:D $attr, :$mooish! ) is export {
    $attr does AttrXMooishAttributeHOW;
    # note "Applying for {$attr.name} to ", $*PACKAGE.WHO, " // ", $*PACKAGE.HOW;
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

    #note "*** Done for {$attr.name} to ", $*PACKAGE.WHO, " // ", $*PACKAGE.HOW;
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
    #depends        => <JSON::Class>,
    test-depends   => <Test Test::META Test::When>,
	#build-depends  => <Pod::To::Markdown>,
    tags           => <AttrX Moo Moose Mooish attribute mooish trait>,
    authors        => ['Vadim Belman <vrurg@cpan.org>'],
    auth           => 'github:vrurg',
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
