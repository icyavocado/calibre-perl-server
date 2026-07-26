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
        like($normal_res->decoded_content, qr/name="view" value="normal"/, 'normal search form preserves normal view');
        like($normal_res->decoded_content, qr{href="(?:https?://[^"/]+)?/\?page=1&view=reader"}, 'normal view switch preserves page');

        my $reader_res = $cb->(GET '/?view=reader');
        is($reader_res->code, 200, 'GET /?view=reader returns 200');
        like($reader_res->decoded_content, qr/Recent Books/, 'reader page contains Recent Books');
        like($reader_res->decoded_content, qr{No downloads available}, 'reader page renders format section state');
        like($reader_res->decoded_content, qr{reader-book-cover}, 'reader page renders cover slot markup');
        unlike($reader_res->decoded_content, qr{pico\.classless\.min\.css}, 'reader page does not load pico css');
        unlike($reader_res->decoded_content, qr{/js/main\.js}, 'reader page does not load app javascript');
        like($reader_res->decoded_content, qr/name="view" value="reader"/, 'reader search form preserves reader view');

        my $cookie_jar = request_cookies($reader_res);
        my $cookie_header = join '; ', map { "$_=$cookie_jar->{$_}" } keys %$cookie_jar;

        my $reader_again_req = GET '/';
        $reader_again_req->header('Cookie' => $cookie_header) if $cookie_header;
        my $reader_again_res = $cb->($reader_again_req);
        like($reader_again_res->decoded_content, qr/Switch to normal view/, 'reader mode persists in session');

        my $normal_again_req = GET '/?view=normal';
        $normal_again_req->header('Cookie' => $cookie_header) if $cookie_header;
        my $normal_again_res = $cb->($normal_again_req);
        like($normal_again_res->decoded_content, qr/View library from e-reader/, 'normal mode can be restored');

        my $ua_req = GET '/';
        $ua_req->header('User-Agent' => 'Mozilla/5.0 Kindle');
        my $ua_res = $cb->($ua_req);
        like($ua_res->decoded_content, qr/Switch to normal view/, 'e-reader user agent gets reader view');
        my $ua_cookie_jar = request_cookies($ua_res);
        my $ua_cookie_header = join '; ', map { "$_=$ua_cookie_jar->{$_}" } keys %$ua_cookie_jar;
        my $desktop_req = GET '/';
        $desktop_req->header('Cookie' => $ua_cookie_header) if $ua_cookie_header;
        my $desktop_res = $cb->($desktop_req);
        like($desktop_res->decoded_content, qr/Switch to normal view/, 'detected reader mode remains fixed in session');

        my $search_res = $cb->(GET '/search?view=reader&q=fixture');
        is($search_res->code, 200, 'reader search returns 200');
        like($search_res->decoded_content, qr/Results for/, 'reader search renders results');
        like($search_res->decoded_content, qr{reader-book-cover}, 'reader search renders cover slot markup');
        like($search_res->decoded_content, qr{href="(?:https?://[^"/]+)?/search\?page=1&q=fixture&view=normal"}, 'search view switch preserves query and page');

        my $normal_search_res = $cb->(GET '/search?view=normal&q=fixture');
        like($normal_search_res->decoded_content, qr/View search from e-reader/, 'normal search has reader switch');
        like($normal_search_res->decoded_content, qr{href="(?:https?://[^"/]+)?/search\?page=1&q=fixture&view=reader"}, 'normal search switch preserves query and page');
    };
};

done_testing();
