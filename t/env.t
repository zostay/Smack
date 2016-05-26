#!perl6

use v6;

use Test;
use lib 't/lib';
use Smack::Test;

my @tests =
    -> $c, $u {
        my $response = $c.get($u);
        ok $response.success, 'request is ok';
    },
    ;

my $test-server = Smack::Test.new(:app<config-env.p6w>, :@tests);
$test-server.run;

my $i = 0;
for $test-server.err.lines {
    $i++;
    # fake TAP
    when /^ \s* "not "? "ok $i" >> [ \s* "#" \s* $<msg> = [ .* ] ]/ { pass($/<msg>) }
    when /^ \s* "#" / { #`{ ignore comments } }
    default { flunk($/<msg>) }
}

done-testing;
