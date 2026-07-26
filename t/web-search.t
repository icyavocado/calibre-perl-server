use strict;
use warnings;

use Test::More;

use Plack::Test;
use HTTP::Request::Common qw(GET);

use lib 't/lib';
use TestFixture qw(fixture_env);
use TestApp qw(build_app);

subtest 'search relevance ranking' => sub {
    my %env = fixture_env();
    $env{CALIBRE_USERDB} = 'test/fixtures/does-not-exist.sqlite';

    my $app = build_app(%env);
    test_psgi $app, sub {
        my $cb = shift;

        my $res = $cb->(GET '/search?q=host');
        is($res->code, 200, 'GET /search?q=host returns 200');

        my $body = $res->decoded_content;
        my $the_host_at = index($body, 'The Host');
        my $ghost_at = index($body, 'Ghost Writer');
        my $ocean_tales_at = index($body, 'Ocean Tales');

        ok($the_host_at >= 0, 'search results include The Host');
        ok($ghost_at >= 0, 'search results include Ghost Writer');
        ok($ocean_tales_at >= 0, 'search results include Ocean Tales');
        cmp_ok($the_host_at, '<', $ghost_at, 'The Host ranks ahead of Ghost Writer for host query');
        like($body, qr/\[\s*Title Matched\s*\]/, 'title match reason is shown');
        like($body, qr/\[\s*Description Matched\s*\]/, 'description match reason is shown');
    };
};

done_testing();
