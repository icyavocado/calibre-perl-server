use strict;
use warnings;

use Test::More;

use Plack::Test;

use HTTP::Request::Common qw(GET);

use lib 't/lib';
use TestFixture qw(fixture_env);
use TestApp qw(build_app);

subtest 'auth enabled, not logged in' => sub {
    my %env = fixture_env();

    my $app = build_app(%env);
    test_psgi $app, sub {
        my $cb = shift;

        my $res_home = $cb->(GET '/');
        is($res_home->code, 401, 'GET / returns 401');
        like($res_home->header('WWW-Authenticate') // q{}, qr{Basic}, 'GET / includes basic auth challenge');

        my $res_home_p2 = $cb->(GET '/?page=2');
        is($res_home_p2->code, 401, 'GET /?page=2 returns 401');

        my $res_search = $cb->(GET '/search?q=fixture');
        is($res_search->code, 401, 'GET /search returns 401');

        my $res_book = $cb->(GET '/book/1');
        is($res_book->code, 401, 'GET /book/1 returns 401');

        my $res_cover = $cb->(GET '/cover/1');
        is($res_cover->code, 401, 'GET /cover/1 returns 401');

        my $res_download = $cb->(GET '/download/1/EPUB');
        is($res_download->code, 401, 'GET /download returns 401');

        unlike($res_home->decoded_content, qr{/book/\d+}, 'GET / body does not leak library links when unauthorized');

        my $res_login = $cb->(GET '/login');
        is($res_login->code, 404, 'GET /login route removed');

        my $res_logout = $cb->(GET '/logout');
        is($res_logout->code, 404, 'GET /logout route removed');

        my $res_opds = $cb->(GET '/opds/v1');
        is($res_opds->code, 401, 'GET /opds/v1 requires basic auth');
        like($res_opds->header('WWW-Authenticate') // q{}, qr{Basic}, 'OPDS includes basic auth challenge');
    };
};

done_testing();
