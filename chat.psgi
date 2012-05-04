my $root;

BEGIN {
    use File::Basename ();
    use File::Spec     ();

    $root = File::Basename::dirname(__FILE__);
    $root = File::Spec->rel2abs($root);

    unshift @INC, "$root/../../lib";
}

use strict;
use utf8;
use warnings;
use PocketIO;
use Plack::App::File;
use Plack::Builder;
use Plack::Middleware::Static;
use Encode;
use Data::Dumper;

use Plack::App::File;
use Plack::Session;
use Plack::Request;

use FindBin;
use lib ("$FindBin::Bin/lib");
use Yairc;
use Yairc::DB;
use Yairc::API::Search;
use Yairc::Login::Twitter;
use Yairc::Login::Simple;
use Yairc::DataStorage::DBI::mysql;
use Yairc::Config;

my $config = Yairc::Config->load_file( $ENV{ YAIRC_CONFIG_FILE } || "$root/config.pl" );
my $dbh = Yairc::DB->new('yairc'); # TODO: 後でなくす
my $data_storage = Yairc::DataStorage::DBI::mysql->new( dbh => $dbh );


builder {
    enable 'Session';
    enable "SimpleLogger", level => 'debug';

    mount '/socket.io/socket.io.js' =>
      Plack::App::File->new(file => "$root/public/socket.io.js");

    mount '/socket.io/static/flashsocket/WebSocketMain.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMain.swf");

    mount '/socket.io/static/flashsocket/WebSocketMainInsecure.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMainInsecure.swf");

    mount '/socket.io' => PocketIO->new( socketio => $config->{ socketio },
                                         instance => Yairc->new( config => $config, data_storage => $data_storage )  
                          );

    # APIリクエストサンプル
    # https://gist.github.com/2440738
    mount '/api' => do ( './api.psgi' ) ;

    mount '/login/twitter' => Yairc::Login::Twitter->new(data_storage => $data_storage)
                                ->build_psgi_endpoint();

    mount '/login'         => Yairc::Login::Simple->new(data_storage => $data_storage)
                                ->build_psgi_endpoint( { name_field => 'nick' } );

    mount '/' => builder {
        enable "Static",
          path => qr/\.(?:js|css|jpe?g|gif|png|html?|swf|ico)$/,
          root => "$root/public";

        mount '/' => Plack::App::File->new( file => "$root/public/chat.html" );
    };

};
