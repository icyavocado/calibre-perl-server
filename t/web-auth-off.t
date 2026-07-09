use strict;
use warnings;

use Test::More;

use Plack::Test;

use HTTP::Request::Common qw(GET POST);

use lib 't/lib';
use TestFixture qw(fixture_env);
use TestApp qw(build_app);

subtest 'auth disabled' => sub {
    my %env = TestFixture::fixture_env();
    $env{CALIBRE_USERDB} = 'test/fixtures/does-not-exist.sqlite';

    my $app = build_app(%env);
    test_psgi $app, sub {
        my $cb = shift;

        my $res_home = $cb->(GET '/');
        is($res_home->code, 200, 'GET / returns 200');
        like($res_home->decoded_content, qr/Recent Books/, 'home page contains Recent Books');

        my $res_home_p2 = $cb->(GET '/?page=2');
        is($res_home_p2->code, 200, 'GET /?page=2 returns 200');
        like($res_home_p2->decoded_content, qr/Page 2/, 'home pagination shows page 2');

        my $res_search = $cb->(GET '/search?q=fixture');
        is($res_search->code, 200, 'GET /search?q=fixture returns 200');
        like($res_search->decoded_content, qr/Search/, 'search page renders');

        my $res_book = $cb->(GET '/book/1');
        is($res_book->code, 200, 'GET /book/1 returns 200');

        my $res_cover = $cb->(GET '/cover/1');
        is($res_cover->code, 200, 'GET /cover/1 returns 200');

        my $res_cover_thumb = $cb->(GET '/cover/1/thumb');
        is($res_cover_thumb->code, 200, 'GET /cover/1/thumb returns 200');
        like($res_cover_thumb->header('Content-Type') // q{}, qr{image/jpeg}, 'cover thumb is jpeg');

        my $res_download = $cb->(GET '/download/1/EPUB');
        is($res_download->code, 200, 'GET /download/1/EPUB returns 200');
        like($res_download->header('Content-Disposition') // q{}, qr/attachment/i, 'download uses attachment disposition');
    };
};

done_testing();
