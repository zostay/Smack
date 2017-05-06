use v6;

class X::Smack::Builder::NoBuilder {
    has Str $.sub;

    method message() {
        "$.sub must be called inside a builder {} block"
    }
}

class X::Smack::Builder::NoApp {
    method message() {
        "No application to build. Your builder {} block must either use mount() or return an app.";
    }
}

# Catching this will result in an app where all the mount() apps are ignored.
# Plack treated this as a warning. I treat it as an error for two reasons:
#   (1) It really implies a mistake that will cause confusion, even with the
#       warning. We might as well stop execution.
#   (2) Exception handling in Perl 6 is amazingly better than Perl 5, so if they
#       really feel like doing this for some reason, let them catch the
#       exception and live with the consequences.
class X::Smack::Builder::UselessMount {
    method message() {
        "You used mount() in a builder {} block, but the last line (app) is not using mount()."
    }
}

class Smack::Builder {
    use Smack::App::URLMap;

    has Callable @.middlewares;
    has Smack::App::URLMap $!urlmap;

    multi method add-middleware(&mw) {
        push @.middlewares, &mw;
        return;
    }

    multi method add-middleware($mw-class, |args) {
        callwith -> &app {
            $mw-class.wrap-that(&app, |args);
        }
    }

    multi method add-middleware-if(Mu $cond, &mw) {
        use Smack::Middleware::Conditional;

        push @.middlewares, -> &app {
            Smack::Middleware::Conditional.wrap-that(&app,
                condition => $cond,
                builder   => &mw,
            );
        }

        return;
    }

    multi method add-middleware-if(Mu $cond, $mw-class, |args) {
        callwith $cond, -> &app {
            $mw-class.wrap-that(&app, |args);
        }
    }

    method mount($location, &app) {
        $!urlmap .= new without $!urlmap;
        $!urlmap.mount($location, &app);
        return;
    }

    method is-mount-used() { defined $!urlmap }

    # This should work fine if you want to allow mount() and an app in your
    # build block. The consequence is that all mount()s are ignored.
    # CATCH { when X::Smack::Builder::UselessMount { .resume } }
    method to-app($app) {
        with $app {
            if $.is-mount-used {
                die X::Smack::Builder::UselessMount.new;
            }

            self.wrap-that($app);
        }
        elsif $.is-mount-used {
            self.wrap-that($!urlmap.to-app);
        }
        else {
            die X::Smack::Builder::NoApp.new;
        }
    }

    method wrap-that(&app is copy) {
        for @.middlewares.reverse -> &mw {
            &app = mw(&app);
        }

        &app;
    }
}

proto enable(|) is export { * }
multi enable(&mw) {
    with $*SMACK-BUILDER {
        .add-middleware(&mw);
    }
    else {
        die X::Smack::Builder::NoBuilder.new(sub => "enable");
    }
}

multi enable($mw-class, |args) {
    with $*SMACK-BUILDER {
        .add-middleware($mw-class, |args);
    }
    else  {
        die X::Smack::Builder::NoBuilder.new(sub => "enable");
    }
}

proto enable-if(|) is export { * }
multi enable-if(Mu $match, &mw) {
    with $*SMACK-BUILDER {
        .add-middleware-if($match, &mw)
    }
    else {
        die X::Smack::Builder::NoBuilder.new(sub => "enable-if");
    }
}

multi enable-if(Mu $match, $mw-class, |args) {
    with $*SMACK-BUILDER {
        .add-middleware-if($match, $mw-class, |args);
    }
    else {
        die X::Smack::Builder::NoBuilder.new(sub => "enable-if");
    }
}

sub mount(Pair $map) is export {
    with $*SMACK-BUILDER {
        .mount($map.key, $map.value);
    }
    else {
        die X::Smack::Builder::NoBuilder.new(sub => "mount");
    }
}

sub builder(&app-builder) is export {
    my $*SMACK-BUILDER = Smack::Builder.new;

    my $app = app-builder();

    $app = $app.to-app if defined $app && $app.^can('to-app');

    $*SMACK-BUILDER.to-app($app);
}
