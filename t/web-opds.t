use strict;
use warnings;

use Test::More;

use MIME::Base64 qw(encode_base64);
use Plack::Test;
use HTTP::Request::Common qw(GET);

use lib 't/lib';
use TestFixture qw(fixture_env);
use TestApp qw(build_app);

subtest 'opds works when auth disabled' => sub {
    my %env = fixture_env();
    $env{CALIBRE_USERDB} = 'test/fixtures/does-not-exist.sqlite';

    my $app = build_app(%env);
    test_psgi $app, sub {
        my $cb = shift;

        my $res = $cb->(GET '/opds/v1');
        is($res->code, 200, 'GET /opds/v1 returns 200');
        like($res->decoded_content, qr{<feed\b}, 'OPDS v1 returns Atom feed');

        my $res_json = $cb->(GET '/opds/v2');
        is($res_json->code, 200, 'GET /opds/v2 returns 200');
        like($res_json->decoded_content, qr{"publications"}, 'OPDS v2 returns JSON payload');
    };
};

subtest 'opds requires and accepts basic auth when auth enabled' => sub {
    my %env = fixture_env();
    my $app = build_app(%env);

    test_psgi $app, sub {
        my $cb = shift;

        my $anon = $cb->(GET '/opds/v1');
        is($anon->code, 401, 'anonymous OPDS request is rejected');

        my $req = GET '/opds/v1';
        my $basic = encode_base64('fixture-user:fixture-pass', '');
        $req->header('Authorization' => "Basic $basic");
        my $res = $cb->($req);

        is($res->code, 200, 'basic auth OPDS request succeeds');
        unlike($res->decoded_content, qr{^1\z}, 'OPDS route no longer returns literal 1');
        like($res->decoded_content, qr{<feed\b}, 'OPDS v1 returns Atom feed body');
    };
};

done_testing();
