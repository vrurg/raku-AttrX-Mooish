use v6.d;
unit role AttrX::Mooish::Helper;

method setup-helpers(Mu \type, $attr) is hidden-from-backtrace {
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
    my %helpers =
        :clearer( anon method () is hidden-from-backtrace { get-attr-obj(self, $attr).clear-attr(self) } ),
        :predicate( anon method () is hidden-from-backtrace { get-attr-obj(self, $attr).is-set( self ) } ),
        ;

    my @aliases = $attr.base-name, |$attr.init-args;

    my $is-public := $attr.has_accessor;
    for %helpers.keys -> $helper {
        next unless $attr."$helper"(); # Don't generate if attribute isn't set
        for @aliases -> $base-name {
            my $helper-name = $attr.opt2method( $helper, :$base-name  );

            AttrX::Mooish::X::HelperMethod.new( :$helper, :$helper-name ).throw
            if $is-public
                ?? type.^declares_method($helper-name)
                !! type.^find_private_method($helper-name);

            my $m = %helpers{$helper};
            $m.set_name( $helper-name );

            if $is-public {
                type.^add_method( $helper-name, $m );
            } else {
                type.^add_private_method( $helper-name, $m );
            }
        }
    }
}