use v6.d;
unit module AttrX::Mooish:ver($?DISTRIBUTION.meta<ver>):auth<zef:vrurg>:api($?DISTRIBUTION.meta<api>);
#use Data::Dump;
use nqp;

use AttrX::Mooish::Attribute;
use AttrX::Mooish::ClassHOW;
use AttrX::Mooish::ParametricRoleHOW;

CHECK {
    die "Rakudo of at least v2019.11 required to run this version of " ~ ::?PACKAGE.^name
        unless $*RAKU.compiler.version >= v2019.11;
}

multi trait_mod:<is>( Attribute:D $attr, :$mooish! ) is export {
    AttrX::Mooish::X::NoNatives.new(:$attr).throw if nqp::objprimspec($attr.type);

    given $*PACKAGE.HOW {
        when Metamodel::ParametricRoleHOW {
            $_ does AttrX::Mooish::ParametricRoleHOW unless $_ ~~ AttrX::Mooish::ParametricRoleHOW;
        }
        when Metamodel::ClassHOW {
            $_ does AttrX::Mooish::ClassHOW unless $_ ~~ AttrX::Mooish::ClassHOW;
        }
        default {
            AttrX::Mooish::X::TypeObject.new(:type($*PACKAGE), :why('it is not a Raku role or class')).throw
        }
    }

    $attr does AttrX::Mooish::Attribute;

    my @opt-list;

    given $mooish {
        when Bool { }
        when Positional | Pair { @opt-list = $mooish.List }
        default { die "Unsupported mooish value type '{$mooish.^name}'" }
    }

    $attr.INIT-FROM-OPTIONS(@opt-list);

    if $attr.lazy && $attr.type.HOW.archetypes.definite && !$attr.required {
        $attr.FAKE-REQUIRED;
    }
}

our sub META6 {
    $?DISTRIBUTION.meta
}

# Copyright (c) 2018, Vadim Belman <vrurg@cpan.org>
#
# Check the LICENSE file for the license

# vim: tw=120 ft=raku
