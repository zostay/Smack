use v6;

use Smack::Client::Request;

my constant DEFAULT-CONFIG =
    'wapi.version'          => v0.9.Draft,
    'wapi.errors'           => Supplier.new,
    'wapi.multithread'      => False,
    'wapi.multiprocess'     => False,
    'wapi.run-once'         => True,
    'wapi.protocol.support' => set('request-response'),
    'wapi.protocol.enabled' => SetHash.new('request-response'),
    ;

class Smack::Test { ... }

class Smack::TestFactory {

    our $DEFAULT_IMPL_NAME = %*ENV<SMACK_TEST_IMPL> // "MockHTTP";

    has $.class;
    has %.config = DEFAULT-CONFIG;

    submethod BUILD(:$name = $DEFAULT_IMPL_NAME, :$!class) {
        without $!class {
            my $DEFAULT_IMPL_CLASS = "Smack::Test::$name";
            require ::($DEFAULT_IMPL_CLASS);
            $!class = ::($DEFAULT_IMPL_CLASS);
        }
    }

    method create(&app, *%args --> Smack::Test:D) {
        $.class.new(:&app, |%args);
    }

}

class Smack::Test {
    our $DEFAULT_TEST_FACTORY;

    has &.app;
    has %.config = DEFAULT-CONFIG;

    method run-config(:&app = &!app, :%config = %!config) {
        if &app.returns ~~ Callable {
            # cache the result so we only configure once
            &!app = app(%config);
            &!app;
        }
        else {
            &app;
        }
    }

    method run-app(%env, :&app = &!app, :%config = %!config) {
        my &the-app := self.run-config(:&app, :%config);
        the-app(%env);
    }

    multi method request(Smack::Client::Request $request --> Promise:D) {
        self.request($request, %.config);
    }

    multi method request(Smack::Client::Request $request, %config --> Promise:D) { ... }

    my sub test-factory { $*TEST_FACTORY // ($DEFAULT_TEST_FACTORY //= Smack::TestFactory.new) }

    proto test-wapi(|) is export { * };

    multi test-wapi($app where { .^can('to-app') }, &client) {
        samewith($app.to-app, &client);
    }

    multi test-wapi(&app, &client) {
        samewith(:&app, :&client);
    }

    multi test-wapi(:&app, :&client, *%args) {
        my $tester = test-factory.create(&app, |%args);
        client($tester);
    }
}
