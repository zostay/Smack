#!smackup

use v6;
sub app(%env) {
    my $channel = Channel.new;
    my @letters = "Hello World".comb(/./);
    $*SCHEDULER.cue: {
        for @letters { $channel.send($_); sleep 1 }
        $channel.close;
    };

    (200, [ Content-Type => 'text/plain' ], $channel);
}
