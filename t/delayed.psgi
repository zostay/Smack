#!spackle

use v6;
sub app(%env) {
    start {
        sleep 1;
        (200, [ Content-Type => 'text/plain' ], [ "Hello World" ]);
    }
}
