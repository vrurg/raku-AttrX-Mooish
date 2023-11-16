use v6.d;
unit role AttrX::Mooish::ParametricRoleHOW:ver($?DISTRIBUTION.meta<ver>):auth($?DISTRIBUTION.meta<auth>):api($?DISTRIBUTION.meta<api>);

use AttrX::Mooish::Attribute;
use AttrX::Mooish::ClassHOW;
use AttrX::Mooish::Helper;

also does AttrX::Mooish::Helper;

method specialize(Mu \r, Mu:U \obj, *@, *%) is hidden-from-backtrace {
    unless obj.HOW ~~ Metamodel::ClassHOW {
        AttrX::Mooish::X::TypeObject.new(:type(obj),
                                         :why('role ' ~ r.^name ~ " can only be consumed by a Raku class")).throw;
    }
    obj.HOW does AttrX::Mooish::ClassHOW unless obj.HOW ~~ AttrX::Mooish::ClassHOW;
    nextsame;
}
