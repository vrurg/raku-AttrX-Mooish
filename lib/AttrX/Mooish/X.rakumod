use v6.d;
unit module AttrX::Mooish::X;

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
