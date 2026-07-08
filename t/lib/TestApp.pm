package TestApp;

use strict;
use warnings;

use Exporter 'import';

use Plack::Test;
use HTTP::Request::Common qw(GET POST);

our @EXPORT_OK = qw(build_app request_cookies post_login);

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

sub post_login {
    my (%args) = @_;
    my $cookie_jar = $args{cookie_jar} || {};
    my ($user, $pass) = @{$args{user_pass}};

    my $cookie_header = join '; ', map { "$_=$cookie_jar->{$_}" } keys %$cookie_jar;
    $cookie_header = undef if $cookie_header && $cookie_header eq '';

    my $req = POST('/login', [
        user => $user,
        password => $pass,
        return_url => '/'
    ]);

    $req->header('Cookie' => $cookie_header) if $cookie_header;
    return $req;
}

1;
