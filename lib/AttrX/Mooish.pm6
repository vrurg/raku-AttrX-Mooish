unit module AttrX::Mooish:ver<0.0.1>:auth<github:vrurg>;
#use Data::Dump;

=begin pod
=head1 NAME

AttrX::Mooish

=head1 SYNOPSIS

    class Foo {
        has $.bar1 is mooish(:lazy, :clearer, :predicate) is rw;
        has $!bar2 is mooish(:lazy, :clearer, :predicate) is rw;

        method build-bar1 {
            "lazy init value"
        }
        
        method build-bar2 {
        }

        method baz {
            # Yes, works with private too! Isn't it magical? ;)
            "Take a look at the magic: «{ $!bar2 }»";
        }
    }

    my $foo = Foo.new;

    say $foo.bar1;

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
                    when 'predicate' {
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

# vim: tw=120 ft=perl6
