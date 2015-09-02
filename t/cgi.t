#!perl6

use v6;

use Test;

my $expected = q:to/END_OF_EXPECTED/;
Status: 200 OK
Content-Type: text/plain

END_OF_EXPECTED
$expected.=subst(/\n/, "\x0d\x0a", :g);
$expected ~= "Hello World";

for <hello hello-supply hello-psgi> -> $name {
    %*ENV<GATEWAY_INTERFACE> = '1';

    my $msg = '';

    my $cgi = Proc::Async.new($*EXECUTABLE, '-Ilib',
        'bin/smackup', "-a=t/apps/$name.p6w");
    $cgi.stdout.tap(-> $v { $msg ~= $v });
    $cgi.stderr.tap(-> $v { diag($v) });
    my $status = await $cgi.start;

    ok($status, 'process exit status is ok');
    is($msg, $expected, 'CGI output expected message');
}

done;
