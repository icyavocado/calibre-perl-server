use strict;
use warnings;

use Test::More;

use Plack::Test;

use HTTP::Request::Common qw(GET POST);

use lib 't/lib';
use TestFixture qw(fixture_env);
use TestApp qw(build_app);

subtest 'auth enabled, not logged in' => sub {
    my %env = fixture_env();

    my $app = build_app(%env);
    test_psgi $app, sub {
        my $cb = shift;

        my $res_home = $cb->(GET '/');
        is($res_home->code, 302, 'GET / returns 302');
        like($res_home->header('Location') // q{}, qr{/login\b}, 'redirects to /login');

        my $res_home_p2 = $cb->(GET '/?page=2');
        is($res_home_p2->code, 302, 'GET /?page=2 returns 302');
        like($res_home_p2->header('Location') // q{}, qr{/login\b}, 'redirects to /login');

        my $res_search = $cb->(GET '/search?q=fixture');
        is($res_search->code, 302, 'GET /search redirects to login');
        like($res_search->header('Location') // q{}, qr{/login\b}, 'redirects to /login');

        my $res_book = $cb->(GET '/book/1');
        is($res_book->code, 302, 'GET /book/1 returns 302');
        like($res_book->header('Location') // q{}, qr{/login\b}, 'redirects to /login');

        my $res_cover = $cb->(GET '/cover/1');
        is($res_cover->code, 302, 'GET /cover/1 returns 302');
        like($res_cover->header('Location') // q{}, qr{/login\b}, 'redirects to /login');

        my $res_download = $cb->(GET '/download/1/EPUB');
        is($res_download->code, 302, 'GET /download redirects to login');
        like($res_download->header('Location') // q{}, qr{/login\b}, 'redirects to /login');

        my $res_login = $cb->(GET '/login');
        is($res_login->code, 200, 'GET /login returns 200');
        like($res_login->decoded_content, qr/Login/, 'login page renders');

        my $res_logout = $cb->(GET '/logout');
        is($res_logout->code, 404, 'GET /logout is not a route');
    };
};

done_testing();
