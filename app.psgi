use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use CalibreServer;

CalibreServer->to_app;
