package CalibreServer::DB;
use strict;
use warnings;

use DBI;
use DBD::SQLite ();

use constant CALIBRE_DB     => ($ENV{CALIBRE_DB} || '/calibre/metadata.db');
use constant CALIBRE_USERDB => ($ENV{CALIBRE_USERDB} || '/calibre/users.sqlite');

my %DBH;
my $HAS_BOOKS_AUTHOR_SORT;

sub _connect {
    my ($path) = @_;

    die "missing database: $path\n" unless -f $path;
    die "database is not readable: $path\n" unless -r $path;

    return DBI->connect(
        "dbi:SQLite:dbname=$path",
        undef,
        undef,
        {
            RaiseError => 1,
            PrintError  => 0,
            AutoCommit  => 1,
            ReadOnly => 1,
            sqlite_unicode => 1,
            sqlite_open_flags => DBD::SQLite::OPEN_READONLY(),
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

sub _name_key {
    my ($value) = @_;
    return q{} unless defined $value;

    my $normalized = lc $value;
    $normalized =~ s/[^a-z0-9]+/ /g;
    $normalized =~ s/^\s+|\s+$//g;

    return q{} if $normalized eq q{};

    my @tokens = sort split /\s+/, $normalized;
    return join q{ }, @tokens;
}

sub _display_title {
    my ($title, $author_sort) = @_;
    return $title unless defined $title;
    return $title unless defined $author_sort && $author_sort =~ /\S/;

    my $prefix = $author_sort . ' - ';
    if (length($title) >= length($prefix) && lc(substr($title, 0, length($prefix))) eq lc($prefix)) {
        my $trimmed = substr($title, length($prefix));
        return $trimmed =~ /\S\S/ ? $trimmed : $title;
    }

    my ($head, $rest) = split / - /, $title, 2;
    if (defined $rest && _name_key($head) ne q{} && _name_key($head) eq _name_key($author_sort)) {
        return $rest =~ /\S\S/ ? $rest : $title;
    }

    return $title;
}

sub _books_has_author_sort {
    return $HAS_BOOKS_AUTHOR_SORT if defined $HAS_BOOKS_AUTHOR_SORT;

    my $cols = metadata_db()->selectall_arrayref(
        q{PRAGMA table_info(books)},
        { Slice => {} },
    );
    my %col = map { ($_->{name} => 1) } @$cols;
    $HAS_BOOKS_AUTHOR_SORT = $col{author_sort} ? 1 : 0;

    return $HAS_BOOKS_AUTHOR_SORT;
}

sub recent_books {
    my ($limit) = @_;
    $limit ||= 10;

    my $author_sort_expr = _books_has_author_sort()
        ? 'books.author_sort'
        : q{COALESCE(GROUP_CONCAT(REPLACE(authors.name, '|', ', '), ', '), '')};

    my $rows = metadata_db()->selectall_arrayref(
        qq{
            SELECT
                books.id,
                books.title,
                $author_sort_expr AS author_sort,
                books.has_cover,
                books.timestamp,
                COALESCE(GROUP_CONCAT(REPLACE(authors.name, '|', ', '), ', '), '') AS authors
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

    $_->{title} = _display_title($_->{title}, $_->{author_sort}) for @$rows;
    return $rows;
}

sub random_books {
    my ($limit) = @_;
    $limit ||= 10;

    my $author_sort_expr = _books_has_author_sort()
        ? 'books.author_sort'
        : q{COALESCE(GROUP_CONCAT(REPLACE(authors.name, '|', ', '), ', '), '')};

    my $rows = metadata_db()->selectall_arrayref(
        qq{
            SELECT
                books.id,
                books.title,
                $author_sort_expr AS author_sort,
                books.has_cover,
                books.timestamp,
                COALESCE(GROUP_CONCAT(REPLACE(authors.name, '|', ', '), ', '), '') AS authors
            FROM books
            LEFT JOIN books_authors_link ON books.id = books_authors_link.book
            LEFT JOIN authors ON authors.id = books_authors_link.author
            GROUP BY books.id
            ORDER BY RANDOM()
            LIMIT ?
        },
        { Slice => {} },
        $limit,
    );

    $_->{title} = _display_title($_->{title}, $_->{author_sort}) for @$rows;
    return $rows;
}

sub all_books {
    my ($limit, $offset) = @_;
    $limit  ||= 100;
    $offset ||= 0;

    my $author_sort_expr = _books_has_author_sort()
        ? 'books.author_sort'
        : q{COALESCE(GROUP_CONCAT(REPLACE(authors.name, '|', ', '), ', '), '')};

    my $rows = metadata_db()->selectall_arrayref(
        qq{
            SELECT
                books.id,
                books.title,
                $author_sort_expr AS author_sort,
                books.has_cover,
                books.timestamp,
                COALESCE(GROUP_CONCAT(REPLACE(authors.name, '|', ', '), ', '), '') AS authors
            FROM books
            LEFT JOIN books_authors_link ON books.id = books_authors_link.book
            LEFT JOIN authors ON authors.id = books_authors_link.author
            GROUP BY books.id
            ORDER BY books.timestamp DESC, books.id DESC
            LIMIT ? OFFSET ?
        },
        { Slice => {} },
        $limit + 1, $offset,
    );

    $_->{title} = _display_title($_->{title}, $_->{author_sort}) for @$rows;
    return $rows;
}

sub search_books {
    my ($query, $limit, $offset) = @_;
    $limit  ||= 10;
    $offset ||= 0;

    my $query_lc = lc($query // q{});
    my $like = '%' . $query_lc . '%';

    my $author_sort_expr = _books_has_author_sort()
        ? 'books.author_sort'
        : q{COALESCE(GROUP_CONCAT(DISTINCT REPLACE(authors.name, '|', ', ')), '')};

    my $rows = metadata_db()->selectall_arrayref(
        qq{
            SELECT
                books.id,
                books.title,
                $author_sort_expr AS author_sort,
                books.has_cover,
                books.timestamp,
                COALESCE(GROUP_CONCAT(DISTINCT REPLACE(authors.name, '|', ', ')), '') AS authors,
                CASE
                    WHEN lower(books.title) = ? THEN 0
                    WHEN lower(books.title) LIKE ? || ' %' THEN 1
                    WHEN lower(books.title) LIKE '% ' || ? || ' %'
                      OR lower(books.title) LIKE '% ' || ? THEN 2
                    WHEN lower(books.title) LIKE '%' || ? || '%' THEN 3
                    WHEN lower(COALESCE(authors.name, '')) LIKE '%' || ? || '%' THEN 4
                    ELSE 5
                END AS rank,
                CASE
                    WHEN lower(books.title) = ? THEN 'Exact Title'
                    WHEN lower(books.title) LIKE ? || ' %' THEN 'Title'
                    WHEN lower(books.title) LIKE '% ' || ? || ' %'
                      OR lower(books.title) LIKE '% ' || ? THEN 'Title'
                    WHEN lower(books.title) LIKE '%' || ? || '%' THEN 'Title'
                    WHEN lower(COALESCE(authors.name, '')) LIKE '%' || ? || '%' THEN 'Author'
                    WHEN lower(COALESCE(tags.name, '')) LIKE '%' || ? || '%' THEN 'Tag'
                    WHEN lower(COALESCE(series.name, '')) LIKE '%' || ? || '%' THEN 'Series'
                    WHEN lower(COALESCE(comments.text, '')) LIKE '%' || ? || '%' THEN 'Description'
                    ELSE 'Unknown'
                END AS match_reason
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
            ORDER BY rank ASC, books.timestamp DESC, books.id DESC
            LIMIT ? OFFSET ?
        },
        { Slice => {} },
        $query_lc, $query_lc, $query_lc, $query_lc, $query_lc, $query_lc,
        $query_lc, $query_lc, $query_lc, $query_lc, $query_lc,
        $query_lc, $query_lc, $query_lc, $query_lc,
        $like, $like, $like, $like, $like,
        $limit + 1, $offset,
    );

    $_->{title} = _display_title($_->{title}, $_->{author_sort}) for @$rows;
    return $rows;
}

sub book_by_id {
    my ($id) = @_;

    my $author_sort_expr = _books_has_author_sort()
        ? 'books.author_sort'
        : q{COALESCE(GROUP_CONCAT(REPLACE(authors.name, '|', ', '), ', '), '')};

    my $book = metadata_db()->selectrow_hashref(
        qq{
            SELECT
                books.id,
                books.title,
                $author_sort_expr AS author_sort,
                books.path,
                books.has_cover,
                books.timestamp,
                books.pubdate,
                COALESCE(GROUP_CONCAT(REPLACE(authors.name, '|', ', '), ', '), '') AS authors,
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

    return undef unless $book;
    $book->{title} = _display_title($book->{title}, $book->{author_sort});
    return $book;
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
