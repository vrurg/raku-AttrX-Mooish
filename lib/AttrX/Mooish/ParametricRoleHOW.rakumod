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

method specialize(Mu \r, Mu:U \obj, *@, *%) is hidden-from-backtrace {
    unless obj.HOW ~~ Metamodel::ClassHOW {
        AttrX::Mooish::X::TypeObject.new(:type(obj),
                                         :why('role ' ~ r.^name ~ " can only be consumed by a Raku class")).throw;
    }
    obj.HOW does AttrX::Mooish::ClassHOW unless obj.HOW ~~ AttrX::Mooish::ClassHOW;
    nextsame;
}
