unit class Smack::Middleware::Head
does Smack::Middleware;

use v6;

method call(%env) {
    $.app.(%env).then(-> $p {
        return $p unless %env<REQUEST_METHOD> eq 'HEAD';
        $p.result[0,1], Supply.from-list([])
    });
}
