use v6.d;
unit module AttrX::Mooish::X:ver($?DISTRIBUTION.meta<ver>):auth($?DISTRIBUTION.meta<auth>):api($?DISTRIBUTION.meta<api>);

class Fatal is Exception { }

class TypeCheck::MooishOption is X::TypeCheck {
    has @.expected is required;
    method expectedn {
        @.expected.map(*.^name).join(" or ")
    }
}

class NotAllowed is Fatal {
    has Str:D $.op is required;
    has Str $.cause;
    method message {
        "Operation '$!op' is not allowed at this time" ~ ($!cause ?? ": $!cause" !! "")
    }
}

class NoNatives is Fatal {
    has Attribute:D $.attr is required;
    method message {
        "Cannot apply to '" ~ $.attr.name
            ~ "' on type '" ~ $.attr.type.^name
            ~ ": natively typed attributes are not supported"
    }
}

class TypeObject is Fatal {
    has Mu $.type is built(:bind) is required;
    has Str:D $.why is required;
    method message {
        "Unsupported typeobject " ~ $!type.^name ~ ": " ~ $.why
    }
}

class Option::Name is Fatal {
    has Str:D $.option is required;
    method message {
        "Unknown named option '$.option'"
    }
}

class Option::Type is Fatal {
    has Mu $.type is required;
    method message {
        "Trait 'mooish' only takes options as Pairs, but a {$.type.^name} encountered"
    }
}

class HelperMethod is Fatal {
    has Str:D $.helper is required;
    has Str:D $.helper-name is required;
    method message {
        "Cannot install {$.helper}: a method with name '$.helper-name' is already defined"
    }
}

class StoreValue is Fatal {
    has Attribute:D $.attribute is required;
BEGIN {
    # X::Wrapper role is only available since around Sep 2023. Use own version with earlier compilers.
    if $*RAKU.compiler.version >= v2023.10 {
        ::?CLASS.^add_role(::('X::Wrapper'));
    }
    else {
        ::?CLASS.^add_role: do { require ::('AttrX::Mooish::X::Wrapper') }
    }
}
    method message {
        "Exception " ~ self.exception.^name ~ " has been thrown while storing a value into " ~ $!attribute.name
            ~ self!wrappee-message(:details)
    }
}
