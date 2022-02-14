CHANGELOG
=========



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

