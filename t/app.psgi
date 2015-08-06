#!smackup

use v6;
sub app(%env) {
    (200, [ Content-Type => 'text/plain' ], [ "Hello World" ]);
}
