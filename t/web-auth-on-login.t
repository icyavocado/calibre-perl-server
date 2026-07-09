use strict;
use warnings;

use Test::More;

use Plack::Test;

use HTTP::Request::Common qw(GET POST);

use lib 't/lib';
use TestFixture qw(fixture_env);
use TestApp qw(build_app request_cookies post_login);

subtest 'auth enabled, logged in' => sub {
    my %env = fixture_env();

    my $app = build_app(%env);
    test_psgi $app, sub {
        my $cb = shift;

        # Step 1: login
        my $login_req = POST('/login', [
            user => 'fixture-user',
            password => 'fixture-pass',
            return_url => '/',
        ]);

        my $login_res = $cb->($login_req);
        like($login_res->header('Location') // q{}, qr{^/}, 'login redirects');

        my $cookie_jar = request_cookies($login_res);
        ok(keys %$cookie_jar, 'session cookie received after login');

        # Step 2: use session cookie for protected endpoints
        my $cookie_header = join '; ', map { "$_=$cookie_jar->{$_}" } keys %$cookie_jar;

        my $req_home = GET '/';
        $req_home->header('Cookie' => $cookie_header);
        my $res_home = $cb->($req_home);
        is($res_home->code, 200, 'GET / returns 200 after login');

        my $req_search = GET '/search?q=fixture';
        $req_search->header('Cookie' => $cookie_header);
        my $res_search = $cb->($req_search);
        is($res_search->code, 200, 'GET /search returns 200 after login');
        like($res_search->decoded_content, qr/Search/, 'search page renders');

        my $req_book = GET '/book/1';
        $req_book->header('Cookie' => $cookie_header);
        my $res_book = $cb->($req_book);
        is($res_book->code, 200, 'GET /book/1 returns 200 after login');

        my $req_cover = GET '/cover/1';
        $req_cover->header('Cookie' => $cookie_header);
        my $res_cover = $cb->($req_cover);
        is($res_cover->code, 200, 'GET /cover/1 returns 200 after login');

        my $req_cover_thumb = GET '/cover/1/thumb';
        $req_cover_thumb->header('Cookie' => $cookie_header);
        my $res_cover_thumb = $cb->($req_cover_thumb);
        is($res_cover_thumb->code, 200, 'GET /cover/1/thumb returns 200 after login');

        my $req_download = GET '/download/1/EPUB';
        $req_download->header('Cookie' => $cookie_header);
        my $res_download = $cb->($req_download);
        is($res_download->code, 200, 'GET /download/1/EPUB returns 200 after login');
        like($res_download->header('Content-Disposition') // q{}, qr/attachment/i, 'download is attachment');
    };
};

done_testing();
