use v6.d;
unit role AttrX::Mooish::ParametricRoleHOW;

use AttrX::Mooish::Attribute;
use AttrX::Mooish::ClassHOW;
use AttrX::Mooish::Helper;

also does AttrX::Mooish::Helper;

method compose(Mu \type, :compiler_services($)) is hidden-from-backtrace {
    for type.^attributes.grep( AttrX::Mooish::Attribute ) -> $attr {
        self.setup-helpers(type, $attr);
    }
    nextsame
    }

method specialize(Mu \r, Mu:U \obj, *@pos_args, *%named_args) is hidden-from-backtrace {
    obj.HOW does AttrX::Mooish::ClassHOW unless obj.HOW ~~ AttrX::Mooish::ClassHOW;
    nextsame;
}
