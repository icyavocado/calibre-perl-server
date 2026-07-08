package TestFixture;

use strict;
use warnings;

use Exporter 'import';

our @EXPORT_OK = qw(fixture_env fixture_root);

sub fixture_root {
    return $ENV{TEST_FIXTURES_ROOT} || 'test/fixtures';
}

sub fixture_env {
    my $root = fixture_root();

    return (
        CALIBRE_ROOT => $root,
        CALIBRE_DB => "$root/metadata.db",
        CALIBRE_USERDB => "$root/users.sqlite",
    );
}

1;
