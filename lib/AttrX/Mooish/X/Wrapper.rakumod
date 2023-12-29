use v6.d;
unit role AttrX::Mooish::X::Wrapper;
use nqp;

has Mu $!exception is required is built(:bind);
has Mu $!ex-payload;
has $!is-raku-exception;

method exception is raw {
    my $ex := nqp::decont($!exception);
    nqp::isconcrete(nqp::decont($!ex-payload))
        ?? $!ex-payload
        !! ($!ex-payload := nqp::istype($ex, Exception) ?? $ex !! (nqp::ifnull(nqp::getpayload($ex), $ex)))
}

method !is-raku-exception {
    $!is-raku-exception //= nqp::istype(self.exception, Exception)
}

method !wrappee-message(:$concise, :$details) {
    my $ex-msg := self!is-raku-exception ?? $!ex-payload.message !! nqp::getmessage($!ex-payload);
    my $message :=
        $concise
            ?? $ex-msg
            !! ($!is-raku-exception
                ?? $!ex-payload.gist
                !! $ex-msg ~ "\n" ~ Backtrace.new(nqp::backtrace($!exception)));
    $details ?? "; exception details:\n\n" ~ $message.indent(4) !! $message
}

method !exception-name-message {
    self!is-raku-exception ?? " with " ~ $!ex-payload.^name !! ""
}
