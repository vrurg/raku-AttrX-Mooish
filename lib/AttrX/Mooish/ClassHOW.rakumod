use v6.d;
unit role AttrX::Mooish::ClassHOW;
use nqp;

use AttrX::Mooish::Attribute;
use AttrX::Mooish::Helper;

also does AttrX::Mooish::Helper;

# BUILDPLAN task codes
my $BP_4_400;
my $BP_8_800;
my $BP_10_1000;

CHECK {
    ($BP_4_400, $BP_8_800, $BP_10_1000) =
        $*RAKU.compiler.version >= v2021.12.176.ga.38.bebecf ?? (400, 800, 1000) !! (4, 8, 10);
}

has $!mooified-attrs;

method compose(Mu \type, :$compiler_services) is hidden-from-backtrace {
    for type.^attributes(:local).grep(AttrX::Mooish::Attribute) -> $attr {
        self.setup-helpers(type, $attr);
    }
    nextsame;
}

method post-clone(Mu \type, Mu:D \orig, Mu:D \cloned, %twiddles) is raw {
    my $force = ?%twiddles;
    my int $elems = $!mooified-attrs.elems;
    my int $i = -1;
    nqp::while(
        (++$i < $elems),
        nqp::stmts(
            (my $attr := $!mooified-attrs[$i]),
            nqp::unless(
                (%twiddles{$attr.base-name}:exists),
                ($attr.fixup-attr(orig, cloned, :$force)))));
    cloned
}

# Install clone fixup method before class method cache is published.
method publish_method_cache(Mu \type) {
    # We're about to install clone fixup. But if there is a parent with a mooified attribute then the method has been
    # already installed and we don't need to do it again.
    unless self.declares_method(type, 'clone') {
        my &clone-meth = anon method clone(*%twiddles) is raw { type.^post-clone: self, callsame(), %twiddles }
        self.add_method(type, 'clone', &clone-meth);
    }
    nextsame;
}

method create_BUILDPLAN(Mu \type) is raw is hidden-from-backtrace {
    $!mooified-attrs := IterationBuffer.new without $!mooified-attrs;

    callsame;

    # note "--- PLAN FOR ", type.^name;
    my \plan := nqp::getattr(self, Metamodel::ClassHOW, '@!BUILDPLAN');
    my \newplan := nqp::create(nqp::what(plan));

    my @mooified;
    for (@mooified = type.^attributes(:local).grep(* ~~ AttrX::Mooish::Attribute)) {
        $!mooified-attrs.push: nqp::decont($_);
    }
    my %seen-attr;
    # To follow the specs, we must not initialize attributes from %attrinit if there is user-defined BUILD.
    my $no-attrinit = False;
    # Those we've already added moofication for

    TASK:
    while @mooified || nqp::elems(plan) {
        my @candidates;
        # explicitly by make-mooish
        if nqp::elems(plan) {
            my $task := nqp::shift(plan);
            #                note "^ PLAN TASK: ", ($task ~~ Code ?? $task.gist !! nqp::hllize($task));
            if nqp::islist($task) {
                my $code = nqp::hllize(nqp::atpos($task, 0));
                #                    note "  . task is a list, code: ", $code, " matches: ", ($code == 0 | $BP_4_400 | $BP_10_1000), ", codes=", ($BP_4_400 | $BP_10_1000);
                if $code == 0 | $BP_4_400 | $BP_10_1000 {
                    # Attribute initialize from constructor arguments
                    my $name = nqp::atpos($task, 2);
                    my $type := nqp::atpos($task, 1);
                    my $attr = $type.^get_attribute_for_usage($name);
                    $name = nqp::box_s($name, Str);
                    #                        note "  ? considering ", $name;
                    if $attr ~~ AttrX::Mooish::Attribute {
                        $attr.SET-HAS-BUILD-CLOSURE if $code == $BP_4_400;
                        next TASK if %seen-attr{$name};
                        # Create a batch of attributes to be moofied, in the order reported. The batch may include
                        # those for which there are no entries in the plan. Like the private ones.
                        loop {
                            with @mooified.shift {
                                @candidates.push: $_;
                                my $cand-name = .name;
                                %seen-attr{$cand-name} = $_;
                                last if $cand-name eq $name;
                            }
                        }
                    }
                }
            }
            elsif $task ~~ Submethod && $task.name eq 'BUILD' {
                $no-attrinit = True;
            }

            nqp::push(newplan, $task) unless @candidates;
        }
        else {
            %seen-attr{@mooified.map(*.name)} = @mooified;
            @candidates.append: @mooified;
            @mooified = ();
        }

        if @candidates {
            my $init-block :=
                $no-attrinit
                ?? my sub TASK-MOOIFY-NO-INIT(Mu $instance is raw, *%) is hidden-from-backtrace {
                    .make-mooish($instance, type, %()) for @candidates;
                }
                !! my sub TASK-MOOIFY(Mu $instance is raw, *%attrinit) is hidden-from-backtrace {
                    .make-mooish($instance, type, %attrinit) for @candidates;
                };
            nqp::push(newplan, $init-block);
        }
    }
    nqp::bindattr(self, Metamodel::ClassHOW, '@!BUILDPLAN', newplan);

    # Now collect @!BUILDALLPLAN. This part's logic is largely copied from Rakudo's Perl6::Metamodel::BUILDPLAN
    #        note "--- ALL PLAN for ", type.^name;
    my $allplan := nqp::create(nqp::what(plan));
    my $noops = False;
    for type.^mro.reverse -> Mu $mro_class is raw {
        my Mu $mro_plan := nqp::getattr($mro_class.HOW, Metamodel::ClassHOW, '@!BUILDPLAN');
        my $i = 0;
        my int $count = nqp::elems($mro_plan);
        while $i < $count {
            my $task := nqp::atpos($mro_plan, $i);
            my $skip = False;
            if nqp::islist($task) {
                my $code = nqp::hllize(nqp::atpos($task, 0));
                my $name = nqp::box_s(nqp::atpos($task, 2), Str);
                if $code == $BP_10_1000 || ($code == $BP_8_800 && (%seen-attr{$name} andthen .phony-required)) {
                    $skip = $noops = True;
                }
            }
            unless $skip {
                nqp::push($allplan, $task);
            }
            ++$i;
        }
    }

    if !$noops && nqp::elems($allplan) == nqp::elems(newplan) {
        $allplan := newplan;
    }

    nqp::bindattr(self, Metamodel::ClassHOW, '@!BUILDALLPLAN', $allplan);
}
