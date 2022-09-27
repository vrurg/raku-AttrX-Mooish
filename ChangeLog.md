CHANGELOG
=========



head
====

v0.8.10

  * Fix accidental early initialization of lazy attributes on older Rakudo versions

head
====

v0.8.9

  * Clearer method would not throw anymore if attribute is still building. It would be just a NOP then.

head
====

v0.8.8

  * Resolve some more rare race conditions

head
====

v0.8.7

  * Fix private attribute helper methods checked for duplicate names in public method tables

  * Fix definite-typed private lazy attributes

head
====

v0.8.6

  * Slightly improve thread-safety

v0.8.5
------

  * Make clearer method thread-safe

v0.8.4
------

  * Tidy up exceptions

v0.8.3
------

  * Fix incorrect handling of uninitialized lazy attributes in concurrent environment

v0.8.2
------

  * Fix a bug with the order of `TWEAK` invocation for inherited classes

v0.8.1
------

  * Make it possible to have definite lazy attributes like:

    has Str:D $.s is mooish(:lazy);

  * Fix incorrect processing of BUILDPLAN on the latest Rakudo builds

  * Fix various cases where attributes were not properly initialized

  * Fix for unbinding not taking place when it had to

v0.8.0
------

Major refactor of code toward increasing reliability.

  * Rely on container type rather tahn on sigil

  * Switch initialization code from wrapping `BUILD` to use of `BUILDPLAN`

v0.7.6
------

  * Minor but important fix for a flapping bug with `state` variables in precompiled code

v0.7.5
------

  * Make sure a builder can return Nil and it will be handled according to Raku specs

v0.7.4
------

Migrate to zef ecosystem.

  * Fix `$*PERL` deprecation warning.

