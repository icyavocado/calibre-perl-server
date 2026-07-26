use strict;
use warnings;

use Test::More;

use MIME::Base64 qw(encode_base64);
use Plack::Test;

use HTTP::Request::Common qw(GET);

use lib 't/lib';
use TestFixture qw(fixture_env);
use TestApp qw(build_app);

subtest 'auth enabled, basic auth succeeds' => sub {
    my %env = fixture_env();

    my $app = build_app(%env);
    test_psgi $app, sub {
        my $cb = shift;
        my $basic = encode_base64('fixture-user:fixture-pass', '');

        my $req_home = GET '/';
        $req_home->header('Authorization' => "Basic $basic");
        my $res_home = $cb->($req_home);
        is($res_home->code, 200, 'GET / returns 200 with basic auth');

        my $req_search = GET '/search?q=fixture';
        $req_search->header('Authorization' => "Basic $basic");
        my $res_search = $cb->($req_search);
        is($res_search->code, 200, 'GET /search returns 200 with basic auth');
        like($res_search->decoded_content, qr/Search/, 'search page renders');

        my $req_book = GET '/book/1';
        $req_book->header('Authorization' => "Basic $basic");
        my $res_book = $cb->($req_book);
        is($res_book->code, 200, 'GET /book/1 returns 200 with basic auth');

        my $req_cover = GET '/cover/1';
        $req_cover->header('Authorization' => "Basic $basic");
        my $res_cover = $cb->($req_cover);
        is($res_cover->code, 200, 'GET /cover/1 returns 200 with basic auth');

        my $req_cover_thumb = GET '/cover/1/thumb';
        $req_cover_thumb->header('Authorization' => "Basic $basic");
        my $res_cover_thumb = $cb->($req_cover_thumb);
        is($res_cover_thumb->code, 200, 'GET /cover/1/thumb returns 200 with basic auth');

        my $req_download = GET '/download/1/EPUB';
        $req_download->header('Authorization' => "Basic $basic");
        my $res_download = $cb->($req_download);
        is($res_download->code, 200, 'GET /download/1/EPUB returns 200 with basic auth');
        like($res_download->header('Content-Disposition') // q{}, qr/attachment/i, 'download is attachment');
        like($res_download->header('Content-Disposition') // q{}, qr/filename\*=/, 'download includes UTF-8 filename parameter');

        my $req_opds = GET '/opds/v1';
        $req_opds->header('Authorization' => "Basic $basic");
        my $res_opds = $cb->($req_opds);
        is($res_opds->code, 200, 'GET /opds/v1 returns 200 with basic auth');
    };
};

done_testing();
