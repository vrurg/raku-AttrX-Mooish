unit module AttrX::Extended:ver<0.0.1>:auth<github:vrurg>;
use Data::Dump;

class X::Fatal is Exception {
    has Str $.message is rw;
}

my %attributes-set;

my role ExtendedClassRole {
    submethod BUILD {
        note "&&& BUILD &&&";
    }
    submethod DESTROY {
        note "&&& DESTROY &&&";
        %attributes-set{self.WHICH}:delete;
    }
}

my role ExtendedAttribute {
    has $.base-name = self.name.substr(2);
    has $.lazy is rw = False;
    has $.builder is rw = 'build-' ~ $!base-name;
    has $.clearer is rw = False;
    has Bool $!is-composing = False;

    method compose( Mu $package ) {
        my $attr = self;
        my $is-private = $.name.substr(1,1) ~~ '!';

        note "*** ExtAttr compose";


        unless $!is-composing {
            callsame;

            note "*** REALLY composing";

            $!is-composing = True;

            if $attr.has_accessor {
                note "Using existing accessor";
                $package.^find_method( $!base-name ).wrap:
                method (|c) is rw {
                    note "{$attr.name} accessor wrapper on {self.WHO}";
                    my &orig-accessor = nextcallee;
                    my $obj = self;
                    Proxy.new(
                        FETCH => method {
                            note "--- FETCH";
                            $attr.build-attr( $obj, :&orig-accessor );
                            note "--- REFERRING the orig-accessor";
                            return $obj.&orig-accessor( |c );
                        },
                        STORE => method ( $val ) {
                            note "Assigning $val of {$val.WHO} to {$attr.type.WHO} (container: {$obj.&orig-accessor.WHO})";
                            $obj.&orig-accessor = $val;
                            $attr.built( $obj );
                        },
                    )
                };
            } else {
                note "Creating own accessor";
                my $accessor =
                method (|) is rw {
                    my $obj = self;
                    note "{$attr.name} custom accessor";
                    Proxy.new(
                        FETCH => method {
                            $attr.build-attr( $obj );
                            $attr.get_value( $obj );
                        },
                        STORE => method ( $val ) {
                            $attr.set_value( $obj, $val );
                            $attr.built( $obj );
                        }
                    );
                };
                if ($is-private) {
                    note "Adding private method";
                    $package.^add_private_method( $!base-name, $accessor );
                } else {
                    note "Adding public method";
                    $package.^add_method( $!base-name, $accessor );
                }
            }

            #unless $package ~~ ExtendedClassRole {
            #    $package.^add_role( ExtendedClassRole );
            #    $package.^compose;
            #}

            $!is-composing = False;

            note "*** DONE composing";
        }
    }

    method is-set ( Mu $obj ) {
        %attributes-set{$obj.WHICH}{$.name};
    }

    method built ( Mu $obj ) {
        %attributes-set{$obj.WHICH}{$.name} = True;
    }

    method build-attr ( Mu $obj, :&orig-accessor) {
        unless self.is-set($obj) {
            note "Calling builder {$!builder} (accessor: {&orig-accessor.WHO})";
            die "No builder method {$!builder} defined" unless $obj.can($!builder);
            note "CAN:", $obj.can($!builder).perl;
            my $val = $obj."{$!builder}"();
            if so &orig-accessor {
                note "--- builder is using orig accessor";
                $obj.&orig-accessor = $val;
            } else {
                note "--- builder is using set_value";
                self.set_value( $obj, $val );
            }
            self.built( $obj );
        }
    }

    #method get_value ( Mu $obj ) {
    #    note "Getting value of {$.name} for {$obj}";
    #    callsame;
    #}

    #method set_value ( Mu $obj, Mu \value ) {
    #    note "Setting value of {$.name} for {$obj} to {value}";
    #    note "Self type: ", self.type;
    #    note "Bad value ({value}) type " ~ value.WHO unless value ~~ self.type;
    #    callsame;
    #    self.built( $obj );
    #}
}

my role GH {
    method compose ( Mu $obj ) {
        note "#### GENERIC COMPOSE on ", $obj.^name;
        my @roles_to_compose := self.roles_to_compose($obj);
        for @roles_to_compose -> $r {
            note "Role:", $r, " // ", $r.HOW;
        }
        callsame;
    }
}

multi trait_mod:<is>( Attribute:D $attr, :$extended! ) is export {
    $attr does ExtendedAttribute;

    $attr.package.HOW does GH unless $attr.package.HOW ~~ GH;

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
