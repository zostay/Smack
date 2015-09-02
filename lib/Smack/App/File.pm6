unit class File does Smack::Component;

use v6;

use Smack::Date;
use Smack::MIME;

has IO::Path $.root;
has IO::Path $.file;
has $.content-type;
has $.encoding;
has $.bytes-at-a-time = 8192;

method call(%env) {
    start {
        my ($file, $path-info) = $.file // self.locate-file(%env);
        return $file if $file ~~ Positional;

        if $path-info {
            %env<smack.file.SCRIPT_NAME> = %env<SCRIPT_NAME> ~ %env<PATH_INFO>;
            %env<smack.file.SCRIPT_NAME>.=subst(/$path-info$/, '');
            %env<smack.file.PATH_INFO> = $path-info;
        }
        else {
            %env<smack.file.SCRIPT_NAME> = %env<SCRIPT_NAME> ~ %env<PATH_INFO>;
            %env<smack.file.PATH_INFO> = '';
        }

        self.serve-path(%env, $file);
    }
}

method locate-file(%env) {
    my $path = %env<PATH_INFO> // '';

    return self.bad-request if $path ~~ /\0/;

    my $docroot = $.root // '.';
    my @path = $path.split(/<[ \\ \/ ]>/);
    if @path {
        @path.shift if $path[0] eq '';
    }
    else {
        @path = '.';
    }

    return self.forbidden if @path.first(/^\.{2,}$/);

    my ($file, @path-info);
    while @path {
        my $try = $docroot.child(@path);
        if self.should-handle($try) {
            $file = $try;
            last;
        }
        elsif !self.allow-path-info {
            last;
        }
        @path-info.unshift: @path.pop;
    }

    return self.not-found unless $file;
    return self.forbidden unless $file.r;

    $file, join("/", "", |@path-info);
}

method allow-path-info { False }

method serve-path(%env, $file) {
    my $content-type = $.content-type
                    // Smack::MIME.mime-type($file)
                    // 'text/plain';

    if $content-type ~~ Callable {
        $content-type = $content-type.($file);
    }

    if $content-type ~~ rx{^text/} {
        $content-type ~= '; charset' ~ ($.encoding // 'utf-8');
    }

    my $fh = $file.open(:r) or return self.forbidden;

    200, [
        Content-Type   => $content-type,
        Content-Length => $file.s,
        Last-Modified  => time2str($file.modified),
    ],
    Supply.on-demand(-> $s {
        $s.emit($fh.read($.bytes-at-a-time))
            until $fh.eof;
        $s.done;
    });
}

method forbidden() {
    403,
    [
        Content-Type   => 'text/plain',
        Content-Length => 9,
    ],
    [ 'Forbidden' ]
}

method bad-request {
    400,
    [
        Content-Type   => 'text/plain',
        Content-Length => 11,
    ],
    [ 'Bad Request' ]
}

method not-found {
    404,
    [
        Content-Type   => 'text/plain',
        Content-Length => 9,
    ],
    [ 'Not Found' ]
}
