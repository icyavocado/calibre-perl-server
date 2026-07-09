package CalibreServer;
use Dancer2;
use Dancer2::Plugin::Auth::Tiny;
use Cwd qw(abs_path);
use HTML::Entities qw(encode_entities);
use File::Spec;
use File::Basename qw(dirname);
use File::Path qw(make_path);
require JSON::MaybeXS;
use MIME::Base64 qw(decode_base64);
use XML::Writer;

use CalibreServer::DB;

set template => 'template_toolkit';
set layout => 'main';

my $APP_ROOT = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));

set views      => File::Spec->catdir($APP_ROOT, 'views');
set public_dir => File::Spec->catdir($APP_ROOT, 'public');

## Session engine: explicit, no external secret needed.
set session => 'Simple';

use constant CALIBRE_ROOT => ($ENV{CALIBRE_ROOT} || '/calibre');
use constant CALIBRE_DB    => ($ENV{CALIBRE_DB} || '/calibre/metadata.db');
use constant CALIBRE_USERDB => ($ENV{CALIBRE_USERDB} || '/calibre/users.sqlite');
use constant CPS_COVER_CACHE => ($ENV{CPS_COVER_CACHE} || '/tmp/cps-cover-cache');

my $AUTH_ENABLED = -f CALIBRE_USERDB ? 1 : 0;
my $JSON = JSON::MaybeXS->new->utf8(1);
my %COVER_VARIANTS = (
    thumb  => { size => '240x360', quality => 75 },
    medium => { size => '640x960', quality => 80 },
);
my $EREADER_UA_RE = qr/(?:kindle|kobo|pocketbook|boox|onyx|eink|e-ink|ereader)/i;

sub _cover_variant_cache_file {
    my ($book_id, $variant) = @_;
    return unless exists $COVER_VARIANTS{$variant};
    return unless defined $book_id && $book_id =~ /^\d+$/;

    my $dir = File::Spec->catdir(CPS_COVER_CACHE, $book_id);
    make_path($dir) unless -d $dir;

    return File::Spec->catfile($dir, "$variant.jpg");
}

sub _book_cover_file {
    my ($book) = @_;
    return unless $book && $book->{has_cover};

    my $cover = File::Spec->catfile(CALIBRE_ROOT, $book->{path}, 'cover.jpg');
    my $real_cover = abs_path($cover) or return;
    return unless index($real_cover, CALIBRE_ROOT) == 0;
    return unless -f $real_cover;

    return $real_cover;
}

sub _ensure_cover_variant {
    my ($source, $book_id, $variant) = @_;
    my $spec = $COVER_VARIANTS{$variant} or return;
    my $target = _cover_variant_cache_file($book_id, $variant) or return;
    return $target if -f $target;

    my $tmp = "$target.$$.tmp";
    my $output = "$tmp\[Q=$spec->{quality}\]";
    open my $old_stderr, '>&', \*STDERR;
    open STDERR, '>', File::Spec->devnull;
    my $ok = system('vipsthumbnail', $source, '-s', $spec->{size}, '-o', $output) == 0;
    open STDERR, '>&', $old_stderr;
    return unless $ok && -f $tmp;
    rename $tmp, $target or return;

    return $target;
}

sub auth_enabled {
    return $AUTH_ENABLED;
}

sub _request_auth_state {
    return 'public' unless auth_enabled();
    return 'authenticated' if session('user');
    return 'authenticated' if _basic_auth_ok();

    return 'anonymous';
}

sub _apply_reader_view_preference {
    my $view = lc(params->{view} // q{});
    return session reader_view => 'reader' if $view eq 'reader';
    return session reader_view => 'normal' if $view eq 'normal';

    return;
}

sub _is_ereader_user_agent {
    my $user_agent = request->header('User-Agent') // q{};
    return $user_agent =~ $EREADER_UA_RE ? 1 : 0;
}

sub _reader_view_active {
    _apply_reader_view_preference();

    my $preference = session('reader_view') // q{};
    return 1 if $preference eq 'reader';
    return 0 if $preference eq 'normal';

    return _is_ereader_user_agent();
}

sub _with_formats {
    my ($books) = @_;

    return [
        map {
            my %book = %$_;
            $book{formats} = CalibreServer::DB::formats_for_book($book{id});
            \%book;
        } @$books
    ];
}

sub _page_number {
    my $value = params->{page} // 1;
    $value = int($value);
    return $value > 0 ? $value : 1;
}

sub _basic_auth_ok {
    return 1 unless auth_enabled();

    my $auth = request->header('Authorization') // q{};
    return 0 unless $auth =~ /^Basic\s+(.*)$/i;

    my $decoded = decode_base64($1);
    my ($user, $password) = split /:/, $decoded, 2;
    return 0 unless defined $user && defined $password;

    my $user_row = CalibreServer::DB::user_by_name($user) or return 0;
    return 0 unless $user_row->{pw} eq $password;
    return 0 unless defined $user_row->{readonly} && ($user_row->{readonly} eq 'y' || $user_row->{readonly} eq 'n');

    return 1;
}

sub _require_basic_auth {
    return 1 unless auth_enabled();
    return 1 if _basic_auth_ok();

    status 401;
    response_header 'WWW-Authenticate' => 'Basic realm="Calibre Perl Server"';
    return 'Authentication required';
}

sub _book_acquisition_links {
    my ($book_id, $formats) = @_;
    my @links;

    for my $format (@$formats) {
        my $href = uri_for("/download/$book_id/$format->{format}");
        push @links, {
            href => "$href",
            type => _mime_for_format($format->{format}),
            format => $format->{format},
            title => $format->{format},
        };
    }

    return \@links;
}

sub _opds_v1_feed {
    my ($title, $self_href, $books, $search_href) = @_;
    my $xml = '';
    open my $fh, '>', \$xml or die "cannot open scalar fh: $!\n";
    my $w = XML::Writer->new(OUTPUT => $fh, ENCODING => 'utf-8', DATA_INDENT => 2, NAMESPACES => 1);
    $w->xmlDecl('utf-8');
    $w->startTag('feed', xmlns => 'http://www.w3.org/2005/Atom', 'xmlns:opds' => 'http://opds-spec.org/2010/catalog');
    $w->dataElement('title', $title);
    $w->emptyTag('link', rel => 'self', href => $self_href, type => 'application/atom+xml;profile=opds-catalog');
    $w->emptyTag('link', rel => 'search', href => $search_href, type => 'application/atom+xml;profile=opds-catalog', templated => 'true');

    for my $book (@$books) {
      $w->startTag('entry');
      $w->dataElement('title', $book->{title});
        $w->emptyTag('link', rel => 'alternate', href => uri_for("/book/$book->{id}"), type => 'text/html');
        if ($book->{has_cover}) {
            $w->emptyTag('link', rel => 'http://opds-spec.org/image/thumbnail', href => uri_for("/cover/$book->{id}"), type => 'image/jpeg');
        }
        for my $link (@{ _book_acquisition_links($book->{id}, $book->{formats}) }) {
            $w->emptyTag('link', rel => 'http://opds-spec.org/acquisition/open-access', href => $link->{href}, type => $link->{type});
        }
        $w->dataElement('id', "urn:calibre:book:$book->{id}");
        $w->dataElement('summary', $book->{authors} // q{});
        $w->endTag('entry');
    }

    $w->endTag('feed');
    $w->end;
    return $xml;
}

sub _opds_v2_feed {
    my ($title, $self_href, $books, $search_href) = @_;

    my $payload = {
        metadata => { title => $title },
        links => [
            { rel => 'self', href => $self_href, type => 'application/opds+json' },
            { rel => 'search', href => $search_href, type => 'application/opds+json', templated => JSON::MaybeXS::true },
        ],
        publications => [
            map {
                {
                    metadata => {
                        title => $_->{title},
                        author => $_->{authors} || q{},
                        identifier => "urn:calibre:book:$_->{id}",
                    },
                    links => [
                        { rel => 'self', href => uri_for("/book/$_->{id}"), type => 'text/html' },
                        map { { rel => 'acquisition', href => $_->{href}, type => $_->{type} } } @{ _book_acquisition_links($_->{id}, $_->{formats}) },
                    ],
                    ($_->{has_cover} ? (images => [ { href => uri_for("/cover/$_->{id}"), type => 'image/jpeg' } ]) : ()),
                }
            } @$books
        ],
    };

    return $JSON->encode($payload);
}

sub _is_public_path {
    my ($path) = @_;

    return 1 if grep { $_ eq $path } qw(/login /logout /favicon.ico /__auth_state);
    return 1 if $path =~ m{^/opds/v[12](?:/|$)};
    return 1 if $path =~ m{^/css(?:/|$)};

    return 0;
}

sub _validate_calibre_library {
    die "missing Calibre library root: " . CALIBRE_ROOT . "\n" unless -d CALIBRE_ROOT;
    die "Calibre library root is not readable: " . CALIBRE_ROOT . "\n" unless -r CALIBRE_ROOT;
    die "missing Calibre metadata database: " . CALIBRE_DB . "\n" unless -f CALIBRE_DB;
    die "Calibre metadata database is not readable: " . CALIBRE_DB . "\n" unless -r CALIBRE_DB;
}

_validate_calibre_library();

hook before_template_render => sub {
    my $tokens = shift;
    $tokens->{auth_state} = _request_auth_state();
    $tokens->{reader_mode} = _reader_view_active();
};

hook before => sub {
    _apply_reader_view_preference();

    return unless auth_enabled();
    return if session('user');
    return if _is_public_path(request->path_info);

    return redirect uri_for('/login', { return_url => request->path_info });
};

get '/login' => sub {
    return redirect '/' unless auth_enabled();

    return template 'login' => { title => 'Login', return_url => params->{return_url} || '/', error => '' };
};

any [ 'get', 'head' ] => '/__auth_state' => sub {
    status 204;
    response_header 'X-Auth-State' => _request_auth_state();
    response_header 'X-Reader-Mode' => _reader_view_active() ? 'reader' : 'normal';
    return q{};
};

post '/login' => sub {
    return redirect '/' unless auth_enabled();

    my $user = params->{user} // '';
    my $password = params->{password} // '';
    my $return_url = params->{return_url} || '/';
    my $user_row = CalibreServer::DB::user_by_name($user);

    if ($user_row && $user_row->{pw} eq $password && defined $user_row->{readonly} && ($user_row->{readonly} eq 'y' || $user_row->{readonly} eq 'n')) {
        session user => $user;
        session readonly => $user_row->{readonly};
        return redirect $return_url;
    }

    return template 'login' => { title => 'Login', return_url => $return_url, error => 'invalid username or password' };
};

post '/logout' => sub {
    session->destroy;
    return redirect '/';
};

get '/' => sub {
    my $reader_mode = _reader_view_active();
    my $page = _page_number();
    my $per_page = 100;
    my $offset = ($page - 1) * $per_page;
    my $books = CalibreServer::DB::all_books($per_page, $offset);
    my $recent_books = CalibreServer::DB::recent_books(10);
    my $has_next = @$books > $per_page ? 1 : 0;
    pop @$books if $has_next;

    if ($reader_mode) {
        $recent_books = _with_formats($recent_books);
        $books = _with_formats($books);
    }

    return template($reader_mode ? 'index_reader' : 'index', {
        title        => 'Calibre Perl Server',
        recent_books => $recent_books,
        books        => $books,
        page         => $page,
        has_prev     => $page > 1 ? 1 : 0,
        has_next     => $has_next,
        auth_enabled => auth_enabled(),
    });
};

get '/search' => sub {
    my $reader_mode = _reader_view_active();
    my $query = params->{q} // q{};
    my $page = _page_number();
    my $per_page = 10;
    my $offset = ($page - 1) * $per_page;
    my $rows = $query eq q{} ? [] : CalibreServer::DB::search_books($query, $per_page, $offset);
    my $has_next = @$rows > $per_page ? 1 : 0;
    pop @$rows if $has_next;

    $rows = _with_formats($rows) if $reader_mode;

    return template($reader_mode ? 'search_reader' : 'search', {
        title        => 'Search',
        query        => $query,
        page         => $page,
        has_prev     => $page > 1 ? 1 : 0,
        has_next     => $has_next,
        recent_books => $rows,
    });
};

get '/book/:id' => sub {
    my $book_id = route_parameters->get('id');
    my $book = CalibreServer::DB::book_by_id($book_id) or pass;

    return template 'book' => {
        title   => $book->{title},
        book    => $book,
        tags    => CalibreServer::DB::tags_for_book($book_id),
        formats => CalibreServer::DB::formats_for_book($book_id),
    };
};

get '/cover/:id' => sub {
    my $book_id = route_parameters->get('id');
    my $book = CalibreServer::DB::book_by_id($book_id) or pass;
    my $real_cover = _book_cover_file($book) or pass;

    return send_file($real_cover, system_path => 1, content_type => 'image/jpeg');
};

get '/cover/:id/:variant' => sub {
    my $book_id = route_parameters->get('id');
    my $variant = route_parameters->get('variant') // q{};
    return pass unless exists $COVER_VARIANTS{$variant};

    my $book = CalibreServer::DB::book_by_id($book_id) or pass;
    my $real_cover = _book_cover_file($book) or pass;
    my $variant_file = _ensure_cover_variant($real_cover, $book_id, $variant) || $real_cover;

    return send_file($variant_file, system_path => 1, content_type => 'image/jpeg');
};

sub _mime_for_format {
    my ($format) = @_;
    $format = uc($format // q{});

    return 'application/epub+zip' if $format eq 'EPUB';
    return 'application/x-mobipocket-ebook' if $format eq 'MOBI';
    return 'application/vnd.amazon.mobi8-ebook' if $format eq 'AZW3';
    return 'application/pdf' if $format eq 'PDF';
    return 'application/x-fictionbook+xml' if $format eq 'FB2';
    return 'text/plain' if $format eq 'TXT';

    return 'application/octet-stream';
}

get '/download/:id/:format' => sub {
    my $book_id = route_parameters->get('id');
    my $requested_format = uc(route_parameters->get('format') // q{});
    my $book = CalibreServer::DB::book_by_id($book_id) or pass;

    my $data_row = CalibreServer::DB::format_for_book($book_id, $requested_format) or pass;
    return pass unless $data_row;

    my $download_name = join q{.}, $data_row->{name}, lc($data_row->{format});
    $download_name =~ s/[\r\n"]/_/g;

    my $file = File::Spec->catfile(CALIBRE_ROOT, $book->{path}, $download_name);
    my $real_file = abs_path($file) or pass;
    return pass unless index($real_file, CALIBRE_ROOT) == 0;
    return pass unless -f $real_file;

    response_header 'Content-Disposition' => qq{attachment; filename="$download_name"};
    return send_file($real_file, system_path => 1, content_type => _mime_for_format($data_row->{format}));
};

get '/opds/v1' => sub {
    return _require_basic_auth();
    my $books = [ map { { %$_, formats => CalibreServer::DB::formats_for_book($_->{id}) } } @{ CalibreServer::DB::recent_books(20) } ];
    my $xml = _opds_v1_feed('Calibre Perl Server', uri_for('/opds/v1'), $books, uri_for('/opds/v1/search?query={query}'));
    content_type 'application/atom+xml;profile=opds-catalog';
    return $xml;
};

get '/opds/v1/recent' => sub {
    return _require_basic_auth();
    my $books = [ map { { %$_, formats => CalibreServer::DB::formats_for_book($_->{id}) } } @{ CalibreServer::DB::recent_books(20) } ];
    my $xml = _opds_v1_feed('Recent Books', uri_for('/opds/v1/recent'), $books, uri_for('/opds/v1/search?query={query}'));
    content_type 'application/atom+xml;profile=opds-catalog';
    return $xml;
};

get '/opds/v1/search' => sub {
    return _require_basic_auth();
    my $query = params->{query} // q{};
    my $books = $query eq q{} ? [] : [ map { { %$_, formats => CalibreServer::DB::formats_for_book($_->{id}) } } @{ CalibreServer::DB::search_books($query, 20, 0) } ];
    pop @$books if @$books > 20;
    my $xml = _opds_v1_feed("Search: $query", uri_for('/opds/v1/search?query=' . $query), $books, uri_for('/opds/v1/search?query={query}'));
    content_type 'application/atom+xml;profile=opds-catalog';
    return $xml;
};

get '/opds/v1/book/:id' => sub {
    return _require_basic_auth();
    my $book_id = route_parameters->get('id');
    my $book = CalibreServer::DB::book_by_id($book_id) or pass;
    my $formats = CalibreServer::DB::formats_for_book($book_id);
    my $xml = _opds_v1_feed($book->{title}, uri_for("/opds/v1/book/$book_id"), [ { %$book, formats => $formats } ], uri_for('/opds/v1/search?query={query}'));
    content_type 'application/atom+xml;profile=opds-catalog';
    return $xml;
};

get '/opds/v2' => sub {
    return _require_basic_auth();
    my $books = [ map { { %$_, formats => CalibreServer::DB::formats_for_book($_->{id}) } } @{ CalibreServer::DB::recent_books(20) } ];
    content_type 'application/opds+json';
    return _opds_v2_feed('Calibre Perl Server', uri_for('/opds/v2'), $books, uri_for('/opds/v2/search?query={query}'));
};

get '/opds/v2/recent' => sub {
    return _require_basic_auth();
    my $books = [ map { { %$_, formats => CalibreServer::DB::formats_for_book($_->{id}) } } @{ CalibreServer::DB::recent_books(20) } ];
    content_type 'application/opds+json';
    return _opds_v2_feed('Recent Books', uri_for('/opds/v2/recent'), $books, uri_for('/opds/v2/search?query={query}'));
};

get '/opds/v2/search' => sub {
    return _require_basic_auth();
    my $query = params->{query} // q{};
    my $books = $query eq q{} ? [] : [ map { { %$_, formats => CalibreServer::DB::formats_for_book($_->{id}) } } @{ CalibreServer::DB::search_books($query, 20, 0) } ];
    pop @$books if @$books > 20;
    content_type 'application/opds+json';
    return _opds_v2_feed("Search: $query", uri_for('/opds/v2/search?query=' . $query), $books, uri_for('/opds/v2/search?query={query}'));
};

get '/opds/v2/book/:id' => sub {
    return _require_basic_auth();
    my $book_id = route_parameters->get('id');
    my $book = CalibreServer::DB::book_by_id($book_id) or pass;
    my $formats = CalibreServer::DB::formats_for_book($book_id);
    content_type 'application/opds+json';
    return _opds_v2_feed($book->{title}, uri_for("/opds/v2/book/$book_id"), [ { %$book, formats => $formats } ], uri_for('/opds/v2/search?query={query}'));
};

true;
