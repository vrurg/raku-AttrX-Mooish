use v6.d;
unit role AttrX::Mooish::Helper:ver($?DISTRIBUTION.meta<ver>):auth($?DISTRIBUTION.meta<auth>):api($?DISTRIBUTION.meta<api>);

use AttrX::Mooish::Attribute;
use AttrX::Mooish::X;

method setup-attr-helpers(Mu \type, $attr, Bool :$missing-only --> Nil) is hidden-from-backtrace {
    my sub get-attr-obj( Mu \obj, $attr ) is raw is hidden-from-backtrace {
        # Can't use $attr to call bind-proxy upon if the original attribute belongs to a role. In this case its
        # .package is not defined.
        # Metamodel::GenericHOW only happens for role attributes
        $attr.package.HOW ~~ Metamodel::GenericHOW
            ?? (
            ( try { obj.^get_attribute_for_usage($attr.name) } )
                || obj.^attributes.grep({ $_.name eq $attr.name }).first
            )
            !! $attr;
    }

    my role MooishHelperMethod[Str:D $for] {
        method for is raw { $for }
    }

    my $attr-name := $attr.name;
    my %helpers =
        clearer =>
            anon method () is hidden-from-backtrace { get-attr-obj(self, $attr).clear-attr(self) } but MooishHelperMethod[$attr-name],
        predicate =>
            anon method () is hidden-from-backtrace { get-attr-obj(self, $attr).is-set( self ) } but MooishHelperMethod[$attr-name];

    my @aliases = $attr.base-name, |$attr.init-args;

    my $is-public := $attr.has_accessor;
    for %helpers.keys -> $helper {
        next unless $attr."$helper"(); # Don't generate if attribute isn't set
        ALIAS:
        for @aliases -> $base-name {
            my $helper-name = $attr.opt2method( $helper, :$base-name  );

            my \existing-method =
                $is-public
                    ?? type.^method_table{$helper-name} // type.^submethod_table{$helper-name}
                    !! type.^private_method_table{$helper-name};

            with existing-method {
                next ALIAS if $_ ~~ MooishHelperMethod && .for eq $attr-name;
                AttrX::Mooish::X::HelperMethod.new( :$helper, :$helper-name ).throw
            }

            my &m := %helpers{$helper}<>;
            &m.set_name( $helper-name ) unless &m.name;

            if $is-public {
                type.^add_method( $helper-name, &m );
            } else {
                type.^add_private_method( $helper-name, &m );
            }
        }
    }

    if $is-public {
        my $orig-accessor := self.method_table(type).{$attr.base-name};
        for $attr.init-args.List -> $alias {
            if self.declares_method(type, $alias) {
                AttrX::Mooish::X::HelperMethod.new( :helper("alias accessor"), :helper-name($alias) ).throw
                    unless $missing-only;
            }
            else {
                type.^add_method($alias, $orig-accessor);
            }
        }
    }
}
