unit class Smack::App::Cascade
does Smack::Component;

has @.apps is required;
has Set %.codes = 404 => True;

method call(%env) {
    my &initial-app = @.apps[0];
    my $p = initial-app(%env);
    return $p unless @.apps.elems > 1;

    # TODO This is a slick solution, but it does too much work. As it is now, a
    # .then() Promise is tacked on for every app and every .then() Promise will
    # run. Once the first application has returned an OK response (or whatever),
    # then the will all resolve quickly, but that's still some unnecessary
    # routines to run.

    for @.apps[1..*] -> &app {
        $p.=then(-> $p {
            my (Int(Any) $status, $headers, $body) = $p.result;
            if %.codes{ $status } {
                app(%env);
            }
            else {
                $status, $headers, $body;
            }
        });
    }

    $p
}
