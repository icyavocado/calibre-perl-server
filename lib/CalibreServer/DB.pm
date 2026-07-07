package CalibreServer::DB;
use strict;
use warnings;

use DBI;

use constant CALIBRE_DB     => '/calibre/metadata.db';
use constant CALIBRE_USERDB => '/calibre/users.sqlite';

my %DBH;

sub _connect {
    my ($path) = @_;

    die "missing database: $path\n" unless -f $path;
    die "database is not readable: $path\n" unless -r $path;

    return DBI->connect(
        "dbi:SQLite:dbname=$path;sqlite_open_flags=SQLITE_OPEN_READONLY",
        undef,
        undef,
        {
            RaiseError => 1,
            PrintError  => 0,
            AutoCommit  => 1,
            sqlite_unicode => 1,
        },
    );
}

sub metadata_db {
    return $DBH{metadata} ||= _connect(CALIBRE_DB);
}

sub user_db {
    return undef unless -f CALIBRE_USERDB;
    return $DBH{user} ||= _connect(CALIBRE_USERDB);
}

sub has_user_db {
    return -f CALIBRE_USERDB ? 1 : 0;
}

sub user_by_name {
    my ($name) = @_;
    my $dbh = user_db() or return undef;

    return $dbh->selectrow_hashref(
        'SELECT id, name, pw, readonly, restriction, session_data, misc_data FROM users WHERE name = ?',
        undef,
        $name,
    );
}

sub user_is_readonly {
    my ($name) = @_;
    my $user = user_by_name($name) or return undef;

    return $user->{readonly} && $user->{readonly} eq 'y' ? 1 : 0;
}

sub validate_user_password {
    my ($name, $password) = @_;
    my $user = user_by_name($name) or return 0;

    return $user->{pw} eq $password ? 1 : 0;
}

sub recent_books {
    my ($limit) = @_;
    $limit ||= 10;

    return metadata_db()->selectall_arrayref(
        q{
            SELECT
                books.id,
                books.title,
                books.has_cover,
                books.timestamp,
                COALESCE(GROUP_CONCAT(authors.name, ', '), '') AS authors
            FROM books
            LEFT JOIN books_authors_link ON books.id = books_authors_link.book
            LEFT JOIN authors ON authors.id = books_authors_link.author
            GROUP BY books.id
            ORDER BY books.timestamp DESC, books.id DESC
            LIMIT ?
        },
        { Slice => {} },
        $limit,
    );
}

sub search_books {
    my ($query, $limit, $offset) = @_;
    $limit  ||= 10;
    $offset ||= 0;

    my $like = '%' . lc($query // q{}) . '%';

    return metadata_db()->selectall_arrayref(
        q{
            SELECT
                books.id,
                books.title,
                books.has_cover,
                books.timestamp,
                COALESCE(GROUP_CONCAT(DISTINCT authors.name), '') AS authors
            FROM books
            LEFT JOIN books_authors_link ON books.id = books_authors_link.book
            LEFT JOIN authors ON authors.id = books_authors_link.author
            LEFT JOIN books_tags_link ON books.id = books_tags_link.book
            LEFT JOIN tags ON tags.id = books_tags_link.tag
            LEFT JOIN comments ON comments.book = books.id
            LEFT JOIN books_series_link ON books.id = books_series_link.book
            LEFT JOIN series ON series.id = books_series_link.series
            WHERE lower(books.title) LIKE ?
               OR lower(COALESCE(authors.name, '')) LIKE ?
               OR lower(COALESCE(tags.name, '')) LIKE ?
               OR lower(COALESCE(comments.text, '')) LIKE ?
               OR lower(COALESCE(series.name, '')) LIKE ?
            GROUP BY books.id
            ORDER BY books.timestamp DESC, books.id DESC
            LIMIT ? OFFSET ?
        },
        { Slice => {} },
        $like, $like, $like, $like, $like, $limit + 1, $offset,
    );
}

sub book_by_id {
    my ($id) = @_;

    return metadata_db()->selectrow_hashref(
        q{
            SELECT
                books.id,
                books.title,
                books.path,
                books.has_cover,
                books.timestamp,
                books.pubdate,
                COALESCE(GROUP_CONCAT(authors.name, ', '), '') AS authors,
                COALESCE(series.name, '') AS series,
                COALESCE(books.series_index, '') AS series_index,
                COALESCE(comments.text, '') AS comment
            FROM books
            LEFT JOIN books_authors_link ON books.id = books_authors_link.book
            LEFT JOIN authors ON authors.id = books_authors_link.author
            LEFT JOIN books_series_link ON books.id = books_series_link.book
            LEFT JOIN series ON series.id = books_series_link.series
            LEFT JOIN comments ON comments.book = books.id
            WHERE books.id = ?
            GROUP BY books.id
        },
        undef,
        $id,
    );
}

sub tags_for_book {
    my ($id) = @_;

    return metadata_db()->selectall_arrayref(
        q{
            SELECT tags.name
            FROM tags
            JOIN books_tags_link ON tags.id = books_tags_link.tag
            WHERE books_tags_link.book = ?
            ORDER BY tags.name
        },
        { Slice => {} },
        $id,
    );
}

sub formats_for_book {
    my ($id) = @_;

    return metadata_db()->selectall_arrayref(
        q{
            SELECT format, name, uncompressed_size
            FROM data
            WHERE book = ?
            ORDER BY format
        },
        { Slice => {} },
        $id,
    );
}

sub format_for_book {
    my ($id, $format) = @_;

    return metadata_db()->selectrow_hashref(
        q{
            SELECT format, name, uncompressed_size
            FROM data
            WHERE book = ? AND upper(format) = upper(?)
            LIMIT 1
        },
        undef,
        $id,
        $format,
    );
}

1;
