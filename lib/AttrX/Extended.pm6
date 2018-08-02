unit module AttrX::Extended:ver<0.0.1>:auth<github:vrurg>;
use Data::Dump;

class X::Fatal is Exception {
    has Str $.message is rw;
}

my %attr-data;

my role AttrXExtendedClassRole[Mu $package] {
    submethod DESTROY {
        #note "&&& DESTROY &&&";
        %attr-data{self.WHICH}:delete;
    }
}

my role AttrXExtendedAttributeHOW {
    has $.base-name = self.name.substr(2);
    has $.lazy is rw = False;
    has $.builder is rw = 'build-' ~ $!base-name;
    has $.clearer is rw = False;

    #`(
    method compose ( Mu \type ) {
        note "^^^ ATTRIBUTE COMPOSE";

        my &my-accessor;
        my $attr = self;

        if $.has_accessor {
            if $.readonly {
                &my-accessor = method () { note "RO ACCESSOR"; $attr.get_value( self ) };
            } else {
                &my-accessor = method () is rw { note "RW ACCESSOR"; my $po := $attr.get_value( self ); note "PO:", $po.VAR.WHAT; $po }; 
            }

            type.^add_method( $!base-name, &my-accessor );
        }

        nextsame;
    }
)

    method check-value ( $value ) {
        if !$value.defined {
            if $.type.HOW ~~ Metamodel::DefiniteHOW {
                die "Cannot assign Nil to a definite attribute {$.name}" unless !$.type.^definite;
            }
        }
        else {
            die "{$value} doesn't match attribute {$.name} type" unless $value ~~ $.type;
        }
    }

    method make-lazy ( Mu $instance ) {
        my $attr = self;
        my $obj-id = $instance.WHICH;

        return if so %attr-data{$obj-id}{$.name};

        #note ">>> LAZIFYING ", $.name;

        my $default = self.get_value( $instance );
        #note "Setting to proxy object";
        self.set_value( $instance, 
            Proxy.new(
                FETCH => -> $ {
                    #note "FETCH of {$.name}";
                    self.build-attr( $instance );
                    %attr-data{$obj-id}{$.name}<value>;
                },
                STORE => -> $, $value {
                    #note "STORE (", self, ")";
                    self.store-value( $instance, $value );
                }
            )
        );
        #note "Storing value in global hash";
        %attr-data{$obj-id}{$.name}<value> = $default;

        #note "<<< DONE LAZIFYING ", $.name;
    }

    method store-value ( Mu $instance, $value ) {
        self.check-value( $value );
        %attr-data{$instance.WHICH}{$.name}<value> = $value;
    }

    method is-set ( Mu $instance ) {
        %attr-data{$instance.WHICH}{$.name}<value>;
    }

    method build-attr ( Mu $instance ) {
        unless self.is-set( $instance ) {
            #note "&&& Calling builder {$!builder}";
            die "No builder method {$!builder} defined" unless $instance.can($!builder);
            my $val = $instance."{$!builder}"();
            #note "Builder-generated value: ", $val;
            self.store-value( $instance, $val );
            #note "Set ATTR";
        }
    }
}

my role AttrXExtendedClassHOW {
    method compose ( Mu:U \type ) {
        #note "+++ composing class ", type.WHO, " of ", type.HOW;
        unless type ~~ AttrXExtendedClassRole[type] {
            #note "*** Adding tole to ", type.WHO;
            type.^add_role( AttrXExtendedClassRole[type] );
            type.^add_trustee( AttrXExtendedClassRole[type] ) unless type.HOW ~~ Metamodel::ParametricRoleHOW;
        }

        #note "+++ checking for stagers";

        # To resolve possible cross-role conflicts of constructors/destructors
        if type.HOW ~~ Metamodel::ClassHOW {
            type.^add_method( 'DESTROY', submethod {} ) unless type.^can( 'DESTROY' );
        }

        my $package = self;
        my &my-buildall = method BUILDALL (|) {
            #note "&&& AUTOGEN BUILDALL &&&";
            $package.on_create( self );
            nextsame;
        }

        #note "CHECKING FOR BUILDALL";
        if my $orig-method = type.^lookup( 'BUILDALL' ) {
            #note "*** WRAPPING BUILDALL ", $orig-method.WHAT;
            $orig-method.wrap( &my-buildall );
        } else {
            #note "*** ADDING BUILDALL";
            type.^add_method( 'BUILDALL', &my-buildall );
        }

        callsame;
        #note "HAS ROLE NOW:", type ~~ AttrXExtendedClassRole[type];
        #note "HAS ROLE NOW 2:", type ~~ AttrXExtendedClassRole;
        #note "+++ done class composition";
    }

    method on_create ( Mu $instance ) {
        my @lazyAttrs = self.attributes( self ).grep( AttrXExtendedAttributeHOW );

        #note "ON CREATE";

        for @lazyAttrs -> $attr {
            #note "Found lazy attr ", $attr.name;
            $attr.make-lazy( $instance );
        }
    }
}

multi trait_mod:<is>( Attribute:D $attr, :$extended! ) is export {
    $attr does AttrXExtendedAttributeHOW;
    $*PACKAGE.HOW does AttrXExtendedClassHOW unless $*PACKAGE.HOW ~~ AttrXExtendedClassHOW;

    my $opt-list = $extended ~~ List ?? $extended !! @$extended;
    for $opt-list.values -> $option {
        given $option {
            when Pair {
                given $option.key {
                    when 'lazy' {
                        $attr.lazy = so $option<lazy>;
                    }
                    when 'builder' {
                        X::Fatal.new( message => "Only builder name (Str) is currently supported" ).throw unless $option<builder> ~~ Str;
                        $attr.builder = $option<builder>;
                    }
                    when 'clearer' {
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

# vim: tw=120 ft=perl6
