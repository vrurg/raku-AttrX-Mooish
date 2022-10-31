use v6.d;
unit role AttrX::Mooish::Attribute;
use nqp;

use AttrX::Mooish::X;

my class AttrProxy is Proxy {
    has Mu $.val;
    has Bool $!is-set is default(False);
    has $!built-promise;
    has $!attribute is built(:bind);
    has $.instance;

    method !SET-SELF(%attrinit) is raw {
        $!attribute := %attrinit<attribute>;
        $!instance := %attrinit<instance>;
        self
    }

    method new(:$FETCH, :$STORE, *%attrinit) is raw {
        callwith(:$FETCH, :$STORE).VAR!SET-SELF(%attrinit)
    }

    method clear {
        return if self.VAR.is-building;
        cas $!is-set, {
            if $_ {
                $!val := Nil;
                $!built-promise ⚛= Nil;
            }
            False
        }
    }

    method build-acquire {
        return False if ⚛$!is-set;
        my $bp = my $bp-old = $!built-promise;
        if !$bp-old.defined && ($bp = cas($!built-promise, $bp-old, Promise.new)) === $bp-old {
            return True;
        }
        await $bp;
        False
    }

    method build-release {
        (⚛$!built-promise).keep;
    }

    method is-set { ⚛$!is-set }

    method is-building {
        ? (.status ~~ Planned with ⚛$!built-promise);
    }

    method store-value(Mu $value is raw) is raw is hidden-from-backtrace {
        unless ⚛$!is-set {
            $!val := nqp::clone_nd($!attribute.auto_viv_container);
            $!is-set ⚛= True;
        }
        nqp::if(
            nqp::iscont($!val),
            ($!val = $value),
            ($!val.STORE($value)));
        $!attribute.unbind-proxy($!instance, $!val)
    }
}

# PvtMode enum defines what privacy mode is used when looking for an option method:
# force: makes the method always private
# never: makes it always public
# as-attr: makes is strictly same as attribute privacy
# auto: when options is defined with method name string then uses attribute mode first; and uses opposite if not
#       found. Always uses attribute mode if defined as Bool
my enum PvtMode <pvmForce pvmNever pvmAsAttr pvmAuto>;

has $.base-name = self.name.substr(2);
has $!always-proxy = False;
has $.lazy = False;
has $.builder = 'build-' ~ $!base-name;
has $.clearer = False;
has $.predicate = False;
has $.trigger = False;
has $.filter = False;
has $.composer = False;
has Bool $.no-init = False;
has @.init-args;
has $!has-build-closure = False;
has $.phony-required = False;
has $!lock is built(:bind) = Lock.new;

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

method INIT-FROM-OPTIONS(@opt-list) {
    sub set-attr($name, $value) {
        self.^get_attribute_for_usage('$!' ~ $name).get_value(self) = $value;
    }

    sub validate-option-type($name, $value, *@expected) {
        AttrX::Mooish::X::TypeCheck::MooishOption.new(
            operation => "setting option {$name} of mooish trait",
            got => $value,
            :@expected
            ).throw
        unless $value ~~ @expected.any
    }

    sub set-callable-opt ($name, $value) {
        validate-option-type($name, $value, Str:D, Callable:D) unless $value ~~ Bool;
        set-attr($name, $value);
    }

    proto sub set-option(|) {*}
    multi sub set-option(Pair:D $opt) {
        samewith($opt.key, $opt.value)
    }
    multi sub set-option(Str:D $name, Mu $value) {
        given $name {
            when 'lazy' {
                unless $value ~~ Bool {
                    samewith 'builder', $value;
                }
                set-attr($name, ?$value);
            }
            when 'builder' | 'trigger' | 'filter' | 'composer' {
                set-callable-opt( $name, $value );
            }
            when 'clearer' | 'predicate' {
                validate-option-type($name, $value, Bool:D, Str:D);
                set-attr($name, $value);
            }
            when 'no-init' {
                set-attr($name, ?$value);
            }
            when 'init-arg' | 'alias' | 'init-args' | 'aliases' {
                validate-option-type($name, $value, Str:D, Positional:D);
                @!init-args.append: $value<>;
            }
            default {
                AttrX::Mooish::X::Option::Name.new( :option($_) ).throw
            }
        }
    }

    multi sub set-option(Mu $opt) {
        AttrX::Mooish::X::Option::Type.new( :type($opt.WHAT) ).throw
    }

    set-option($_) for @opt-list;

}

method opt2method( Str $oname, Str :$base-name? ) is hidden-from-backtrace {
    self!bool-str-meth-name( self."$oname"(), %opt2prefix{$oname}, :$base-name );
}

method SET-HAS-BUILD-CLOSURE { $!has-build-closure = True }

method FAKE-REQUIRED {
    return if self.required; # Already explicitly set
    nqp::bindattr(self, Attribute, '$!required', 1);
    $!phony-required = True;
}

method set_required(Mu $required) {
    $!phony-required = False if $required;
    nextsame
    }

method compose(Mu \type, :$compiler_services) is hidden-from-backtrace {
    return if try nqp::getattr_i(self, Attribute, '$!composed');

    $!always-proxy = $!filter || $!trigger;

    for @!init-args -> $alias {
        my $meth := $compiler_services.generate_accessor(
            $alias, nqp::decont(type), $.name, nqp::decont( $.type ), $.rw ?? 1 !! 0
            );
        type.^add_method( $alias, $meth );
    }

    callsame;

    self.invoke-composer( type );
}

method make-mooish(Mu $instance is raw, Mu $type is raw, %attrinit) is hidden-from-backtrace {
    my Mu $attr-var := self.get_value($instance);

    return if nqp::istype_nd($attr-var, AttrProxy);

    #        note "? mooifying ", $.name, " of ", $.type.^name, " on ", self.package.^name;
    #        note "  = ", $type.WHICH;

    my $initialized = False;
    my Mu $init-value;
    my $constructor;

    unless $!no-init {
        #            note "  . try from attrinit";
        with ($!base-name, |@!init-args).grep( { %attrinit{$_}:exists } ).head {
            $constructor = $initialized = True;
            $init-value := nqp::decont(%attrinit{$_});
            #                note "  . . inited";
        }
    }

    if !$initialized && $!has-build-closure {
        #            note "  . init from build closure";
        my Mu $build := self.build;
        $init-value = $build ~~ Block ?? $build($instance, self) !! nqp::decont($build);
        $initialized = True;
    }

    if !$initialized && nqp::istype_nd($attr-var, Scalar) {
        my Mu $default := nqp::decont(self.container_descriptor.default);
        $default := $default.^nominalize if $default.HOW.archetypes.nominalizable;
        my Mu $attr_type := nqp::decont(self.container_descriptor.of);
        $attr_type := $attr_type.^nominalize if $attr_type.HOW.archetypes.nominalizable;
        #            note "  . default: ", $default.WHICH, " of ", $default.HOW.^name;
        #            note "  . container descriptor of ", $attr_type.WHICH;
        #            note "  . auto viv: ", self.auto_viv_container.VAR.^name;
        unless $default =:= nqp::decont($attr_type) || ($default =:= Any) {
            # If default is different from attribute type then it was manually specified
            $initialized = True;
            $init-value := $default;
            #                note "  . init from default: ", $default.WHICH, " vs. ", self.container_descriptor.of.WHICH;
        }
    }

    #        note "? initialized ", $initialized, ", init-value: ", $init-value.WHICH;

    if $initialized && !$!always-proxy {
        # No need to bind proxy when there is default value and no filter or trigger set.
        nqp::if(
            nqp::iscont($attr-var),
            ($attr-var = $init-value),
            ($attr-var.STORE($init-value)));
    }
    else {
        my $attr-var := self.attr-var: $instance, :$type, :proxify;
        self.store-with-cb( $instance, $attr-var, $init-value, \( :$constructor ) )
        if $initialized;
    }

}

my class NO-VALUE-YET {}
method attr-var( Mu $instance is raw,
                 &code?,
                 Mu :$type is raw = self.package,
                 Bool :$proxify
                ) is raw is hidden-from-backtrace
{
    my Mu $attr-var;
    my Mu $rc;

    nqp::lock($!lock);
    CATCH { nqp::unlock($!lock); .rethrow }

    $attr-var := self.get_value($instance);
    # Don't let the newly created proxy to .sink
    my $ :=
        nqp::unless(
        (nqp::istype_nd($attr-var, AttrProxy) || !$proxify),
            nqp::bindattr(nqp::decont($instance), $type, $.name,
                ($attr-var := AttrProxy.new(
                    :attribute(self),
                    :$instance,
                    FETCH => my sub ($proxy) is raw is hidden-from-backtrace {
                        my $attr-var := nqp::decont($proxy);
                        my Mu $val := NO-VALUE-YET;

                        if !$attr-var.VAR.is-set {
                            if $!lazy {
                                if $attr-var.VAR.build-acquire {
                                    LEAVE $attr-var.VAR.build-release;
                                    $val := self.build-attr($instance, $attr-var);
                                }
                            }
                            else {
                                $val := nqp::clone_nd(self.auto_viv_container);
                            }
                        }

                        if $val =:= NO-VALUE-YET {
                            $val := $attr-var.VAR.val;
                        }

                        $val
                    },
                    STORE => my sub ($proxy, Mu $value is raw) is hidden-from-backtrace {
                        self.store-with-cb( $instance, nqp::decont($proxy), $value );
                    }))));
    with &code { $rc := &code($attr-var) }

    nqp::unlock($!lock);

    &code ?? $rc !! $attr-var
}

method unbind-proxy(Mu $instance is raw, Mu $val is raw) is hidden-from-backtrace {
    my $attr-var := self.get_value($instance);
    unless $!always-proxy or !nqp::istype_nd($attr-var, AttrProxy) {
        self.set_value($instance, $val);
    }
    $val
}

method store-with-cb( Mu $instance is raw,
                      Mu $attr-var is raw,
                      Mu $value is raw,
                      Capture:D $params is copy = \()
                     ) is raw is hidden-from-backtrace
{
    $params = \( |$params, :old-value( nqp::clone($attr-var.VAR.val) ) ) if $attr-var.VAR.is-set;
    my Mu $filtered := $!filter ?? self.invoke-filter( $instance, $value, $params ) !! $value;
    my $rval := $attr-var.VAR.store-value($filtered);
    self.invoke-opt( $instance, 'trigger', \( $filtered, |$params ), :strict ) if $!trigger;
    $rval
}

method is-set(Mu \obj) is hidden-from-backtrace {
    my $attr-var := self.get_value(obj);
    my $rc := nqp::if(
        nqp::istype_nd($attr-var, AttrProxy),
        nqp::getattr($attr-var, AttrProxy, '$!is-set'),
        True);
    $rc
}

method clear-attr(Mu \obj --> Nil) is hidden-from-backtrace {
    my $attr-var := self.attr-var: obj, :proxify;
    nqp::if(nqp::istype_nd($attr-var, AttrProxy), $attr-var.VAR.clear);
}

method invoke-filter(Mu \instance, Mu $value is raw, Capture:D $params = \()) is raw is hidden-from-backtrace {
    $!filter
        ?? self.invoke-opt( instance, 'filter', \($value, |$params), :strict )
        !! $value
}

method invoke-opt( Mu $invocant,
                   Str $option,
                   Capture:D $params = \(),
                   :$strict = False,
                   PvtMode :$private is copy = pvmAuto
                  ) is raw is hidden-from-backtrace
{
    my $opt-value = self."$option"();
    my \type = nqp::decont($.package);

    return unless so $opt-value;

    my $invoke-params = \( |$params, :attribute($.name) );

    my $method;

    sub get-method( $name, Bool $public ) {
        $public ??
        $invocant.^find_method( $name, :no_fallback(1) )
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
                    :$invocant,
                    method => $opt-value,
                    private =>!$is-pub,
                    typename => $invocant.WHAT.^name,
                    ).throw;
            }
        }
        when Callable {
            $method = $opt-value;
        }
        default {
            die "Bug encountered: $option is of unsupported type {$opt-value.^name}";
        }
    }

    $invocant.$method(|$invoke-params)
}

method build-attr(Mu $instance is raw, Mu $attr-var is raw) is raw is hidden-from-backtrace {
    my Mu $val := self.invoke-opt( $instance, 'builder', :strict );
    #        note "= built value: ", $val.WHICH;
    self.store-with-cb( $instance, $attr-var, $val, \( :builder ) )
}

method invoke-composer(Mu \type) is hidden-from-backtrace {
    return unless $!composer;
    my $comp-name = self.opt2method( 'composer' );
    my &composer = type.^find_private_method( $comp-name );
    X::Method::NotFound.new(:method($comp-name), :private, :typename(type.^name)).throw
    unless &composer;
    type.&composer();
}
