use strict;
use warnings;

use Test::More;

use Plack::Test;
use HTTP::Request::Common qw(GET);

use lib 't/lib';
use TestFixture qw(fixture_env);
use TestApp qw(build_app request_cookies);

subtest 'reader mode' => sub {
    my %env = fixture_env();
    $env{CALIBRE_USERDB} = 'test/fixtures/does-not-exist.sqlite';

    my $app = build_app(%env);
    test_psgi $app, sub {
        my $cb = shift;

        my $normal_res = $cb->(GET '/');
        is($normal_res->code, 200, 'GET / returns 200');
        like($normal_res->decoded_content, qr/View library from e-reader/, 'normal page has reader link');

        my $reader_res = $cb->(GET '/?view=reader');
        is($reader_res->code, 200, 'GET /?view=reader returns 200');
        like($reader_res->decoded_content, qr/Recent Books/, 'reader page contains Recent Books');
        like($reader_res->decoded_content, qr{EPUB}, 'reader page contains direct format links');
        unlike($reader_res->decoded_content, qr{/cover/}, 'reader page has no cover URLs');

        my $cookie_jar = request_cookies($reader_res);
        my $cookie_header = join '; ', map { "$_=$cookie_jar->{$_}" } keys %$cookie_jar;

        my $reader_again_req = GET '/';
        $reader_again_req->header('Cookie' => $cookie_header) if $cookie_header;
        my $reader_again_res = $cb->($reader_again_req);
        like($reader_again_res->decoded_content, qr/View normal site/, 'reader mode persists in session');

        my $normal_again_req = GET '/?view=normal';
        $normal_again_req->header('Cookie' => $cookie_header) if $cookie_header;
        my $normal_again_res = $cb->($normal_again_req);
        like($normal_again_res->decoded_content, qr/View library from e-reader/, 'normal mode can be restored');

        my $ua_req = GET '/';
        $ua_req->header('User-Agent' => 'Mozilla/5.0 Kindle');
        my $ua_res = $cb->($ua_req);
        like($ua_res->decoded_content, qr/View normal site/, 'e-reader user agent gets reader view');

        my $search_res = $cb->(GET '/search?view=reader&q=fixture');
        is($search_res->code, 200, 'reader search returns 200');
        like($search_res->decoded_content, qr/Results for/, 'reader search renders results');
        unlike($search_res->decoded_content, qr{/cover/}, 'reader search has no cover URLs');
    };
};

done_testing();
