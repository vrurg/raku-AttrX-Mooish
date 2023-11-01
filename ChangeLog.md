# CHANGELOG

  - v1.0.6
    
      - A quick fix for containerization problem with helper methods

  - v1.0.5
    
      - Increase reliability of initialization

  - v1.0.4
    
      - Fix an exception when mixin in roles with aliased attributes

  - v1.0.3
    
      - Minor fix of an exception not thrown properly

  - v1.0.2
    
      - Provide better error reporting for impossible usages
    
      - Make sure `AttrX::Mooish` works equally well with either NQP or Raku implementation of Metamodel classes

  - v1.0.0
    
      - Implement/fix support of object cloning

  - v0.8.10
    
      - Fix accidental early initialization of lazy attributes on older Rakudo versions

  - v0.8.9
    
      - Clearer method would not throw anymore if attribute is still building. It would be just a NOP then.

  - v0.8.8
    
      - Resolve some more rare race conditions

  - v0.8.7
    
      - Fix private attribute helper methods checked for duplicate names in public method tables
    
      - Fix definite-typed private lazy attributes

  - v0.8.6
    
      - Slightly improve thread-safety

  - v0.8.5
    
      - Make clearer method thread-safe

  - v0.8.4
    
      - Tidy up exceptions

  - v0.8.3
    
      - Fix incorrect handling of uninitialized lazy attributes in concurrent environment

  - v0.8.2
    
      - Fix a bug with the order of `TWEAK` invocation for inherited classes

  - v0.8.1
    
      - Make it possible to have definite lazy attributes like:
        
        ``` 
        has Str:D $.s is mooish(:lazy);
        ```
    
      - Fix incorrect processing of BUILDPLAN on the latest Rakudo builds
    
      - Fix various cases where attributes were not properly initialized
    
      - Fix for unbinding not taking place when it had to

  - v0.8.0
    
    Major refactor of code toward increasing reliability.
    
      - Rely on container type rather tahn on sigil
    
      - Switch initialization code from wrapping `BUILD` to use of `BUILDPLAN`

  - v0.7.6
    
      - Minor but important fix for a flapping bug with `state` variables in precompiled code

  - v0.7.5
    
      - Make sure a builder can return Nil and it will be handled according to Raku specs

  - v0.7.4
    
      - Migrate to zef ecosystem.
    
      - Fix `$*PERL` deprecation warning.

# SEE ALSO

[`AttrX::Mooish`](docs/md/AttrX/Mooish.md)

# LICENSE

Artistic License 2.0

See the [*LICENSE*](LICENSE) file in this distribution.
