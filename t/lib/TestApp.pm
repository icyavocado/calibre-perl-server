package TestApp;

use strict;
use warnings;

use Exporter 'import';

use Plack::Test;
use HTTP::Request::Common qw(GET);

our @EXPORT_OK = qw(build_app request_cookies);

sub build_app {
    my (%env) = @_;

    while (my ($k, $v) = each %env) {
        $ENV{$k} = $v;
    }

    # Ensure module load sees the fixture env vars.
    delete $INC{'CalibreServer.pm'};
    delete $INC{'CalibreServer/DB.pm'};

    require CalibreServer;
    return CalibreServer->to_app;
}

sub request_cookies {
    my ($res) = @_;
    return {} unless $res && $res->headers;

    my $set_cookie = $res->header('Set-Cookie') // $res->headers->header('Set-Cookie');
    return {} unless defined $set_cookie && $set_cookie ne '';

    # In this app/tests we only need the main session cookie.
    # Example: dancer.session=VALUE; Path=/; HttpOnly
    my %cookies;
    if ($set_cookie =~ /^([^=;\s]+)=([^;]+)/) {
        $cookies{$1} = $2;
    }

    return \%cookies;
}

1;
