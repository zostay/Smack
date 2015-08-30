use Smack::Middleware;

unit class Smack::Middleware::PSGI is Smack::Middleware;

use v6;

method call(%env) {
    my $encoding =

    my class InputWrapper {
        has $.input;
        multi method read(Blob $buf is rw, $len, $offset = 0) {
            $.input.seek($offset, 1);
            $buf = $.input.read($len);
            $buf.bytes;
        }
        multi method read($buf is rw, $len, $offset = 0) {
            $.input.seek($offset, 1);
            my $blob = $.input.read($len);
            $buf = $blob.decode($encoding);
            $blob.bytes;
        }
        multi method seek($pos, $whence = 0) {
            $.input.seek($pos, $whence);
        }
    }

    my $input = InputWrapper.new(input => %env<p6sgi.input>);

    # Install PSGI environment
    %env = %env,
        'psgi.version'      => [ 1, 1 ],
        'psgi.url_scheme'   => %env<p6sgi.url-scheme>,
        'psgi.input'        => $input,
        'psgi.errors'       => %env<p6sgi.errors>,
        'psgi.multithread'  => %env<p6sgi.multithread>,
        'psgi.multiprocess' => %env<p6sgi.multiprocess>,
        'psgi.run_once'     => %env<p6sgi.run-once>,
        'psgi.nonblocking'  => %env<p6sgi.nonblocking>,
        'psgi.streaming'    => True,
        ;

    do given &.app.(%env) {
        when Positional { $_ }
        when Callable {
            my @response;

            .(-> @res {
                if @res.elems == 3 {
                    @response = @res;
                }
                elsif @res.elems == 2 {
                    my Channel $q .= new;

                    @response = @res[0, 1], Supply.on-demand(-> $s {
                        loop {
                            my $t = $q.receive;
                            $s.emit($t);
                        }

                        CATCH {
                            when X::Channel::ReceiveOnClosed {
                                $s.done;
                            }
                        }
                    });

                    my $writer = class {
                        multi method write(Str $str) { $q.send($str) }
                        multi method write(Blob $b)  { $q.send($b) }
                        multi method close()         { $q.close }
                    }.new;
                }
                else {
                    die 'Wrong number of elements in application response.';
                }
            });

            @response;
        }
        default {
            die 'Unknown application response: ', .perl;
        }
    }
}
