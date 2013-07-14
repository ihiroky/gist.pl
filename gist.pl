#!/usr/bin/perl
#
# Gist command line tool.
# Excecute this script without options and arguments to show an usage.

use strict;
use warnings;
use utf8;
use LWP::UserAgent;
use JSON::PP;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use File::Basename;
use File::Path;
use Data::Dumper;
use Gtk2 -init;

my $base_url = 'https://api.github.com';
my $since_format = '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z';
my $token_dir = "$ENV{'HOME'}/.github";
my $token_file = "gist-token.json";
my $verbose = 0;

sub usage_and_exit($) {
    my ($msg) = @_;

    print "$msg\n" if defined $msg;
    print <<"EOS";
usage: gist.pl <command> [options...] [arguments...]
commands and options:
    clone
        Clones a specified gist.
            -d|--dir <directory> : optinal
    create
        Creates a new gist, which files is specified with arguments
        or the clipboard. The gist id is copied to the clipboard.
            --desc <description> : optional
                A description for the gist.
            --private : optional
                Creates the gist as private. If not speciied, the gist gets public.
            -e|--embed : optinal
                Copies the script tag for embedding to the clipboard instead of gist id.
            -f|--filename : required if using clipboard for input
                A file name for a content of the clipboard. The arguments are ignored.
                A directory to which the gist is cloned to.
    delete
        Deletes a specified gist.
            -i|--id <id> : required
                The gist id to delete.
    get
        Gets a specified gist. 
            -i|--id <id> : required
                The gist id to retrieve.
            -d|--dir <directory> : optinal
                A directory to which files is save_filed. Default is '.'.
    list
        Lists gists.
            -u|--uid <uid> : required
                An user ID for the gist list
            -s|--since <YYYY-MM-DDTHH:MM:SSZ> : optinal
                Lists gists updated at or after this time are returned.
    login
        Creates the api access token. The token is added to
        https://github.com/settings/applications and is save to "$token_dir/$token_file".
EOS
    exit 1;
}

sub debug($) {
    my ($msg) = @_;
    print "$msg\n" if $verbose;
}

sub http_get($$) {
    my ($url, $token) = @_;

    debug("GET $url");
    my $req = HTTP::Request->new(GET => $url);
    if (defined $token) {
        $req->header('Authorization' => "token $token");
    }
    return LWP::UserAgent->new->request($req);
}

sub http_post($$$) {
    my ($url, $token, $content) = @_;

    debug("PUT $url $content");
    my $req = HTTP::Request->new(POST => $url);
    $req->header('Authorization' => "token $token");
    $req->content($content);
    return LWP::UserAgent->new->request($req);
}

sub http_delete($$) {
    my ($url, $token) = @_;

    debug("DELETE $url");
    my $req = HTTP::Request->new(DELETE => $url);
    $req->header('Authorization' => "token $token");
    return LWP::UserAgent->new->request($req);
}

sub exit_if_failed($) {
    my ($res) = @_;

    my $code = $res->code;
    my $message = $res->message;
    debug("Response code: $code");
    die "FAILED: $code $message" if $res->is_error;
}

sub save_file($$$) {
    my ($dir, $file, $content) = @_;
    open my $fh, ">$dir/$file" or die $!;
    print $fh $content;
    close $fh;
}

sub read_stdin($$) {
    my ($prompt, $echo) = @_;
    my $pass;
    while (!$pass) {
        print "$prompt ";
        system "stty -echo" if not $echo;
        chomp($pass = <STDIN>);
        if (not $echo) {
            system "stty echo";
            print "\n";
        }
    }
    return $pass;
}

sub login() {
    print "Create OAuth token to $token_dir/$token_file\n";
    my $uid = read_stdin("User ID:", 1);
    my $pass = read_stdin("Password:", 0);
    my $url = "$base_url/authorizations";

    my $req = HTTP::Request->new(POST => $url);
    $req->content_type('application/x-www-form-urlencoded');
    $req->content('{"scopes":["gist"],"note":"gist.pl"}');
    $req->authorization_basic($uid, $pass);
    my $res = LWP::UserAgent->new->request($req);
    exit_if_failed($res);

    File::Path::mkpath($token_dir, 1, 0700);
    save_file($token_dir, $token_file, $res->content);
    chmod 0600, "$token_dir/$token_file";
    print "A new token is added to your https://github.com/settings/applications\n";
    print "The token is saved to $token_dir/$token_file.\n"
}

sub load_token() {
    open(my $fd, "<$token_dir/$token_file") or die $!;
    my $json = decode_json(join("", <$fd>));
    my $token = $json->{'token'};
    close $fd;
    debug("token: $token");
    return $token;
}

sub list_gists($$$) {
    my ($token, $uid, $since) = @_;

    usage_and_exit("-u <uid> is required.") if not defined $uid;
    if (defined $since && $since =~ /$since_format/) {
        usage_and_exit("$since must be YYYY-MM-DDTHH:MM:SSZ");
    }

    my $url = "$base_url/users/$uid/gists";
    $url = "$url?since=$since" if defined $since;
    my $res = http_get($url, $token);
    exit_if_failed($res);

    my $json = decode_json($res->content);
    foreach my $e (@$json) {
        print "id:$e->{id}";
        print " private" if not $e->{public};
        print "\n";
        my @lines = split(/\n/, $e->{description});
        for my $line (@lines) {
            print "  $line\n";
        }
    }
}

sub valid_raw_url($$$) {
    my ($url, $owner, $id) = @_;

    my $original_url = $url;
    $url =~ s/raw/$owner/;
    $url =~ s#$id#$id/raw#;
    debug("new raw_url: [$url], original: [$original_url]");
    return $url;
}

sub load_file($) {
    my ($file) = @_;
    open my $fh, "<$file" or die $!;
    my $content = join('', <$fh>);
    close $fh;
    return $content;
}

sub get_gist($$$) {
    my ($token, $id, $dir) = @_;
    usage_and_exit("--id <id> is required.") if not defined $id;
    my $res = http_get("$base_url/gists/$id", $token);
    exit_if_failed($res);

    my $json = decode_json($res->content);
    my $owner = $json->{user}->{login};
    File::Path::mkpath($dir);
    foreach my $file (values $json->{files}) {
        my $name = $file->{filename};
        my $url = valid_raw_url($file->{raw_url}, $owner, $id);
        my $res = http_get($url, undef);
        exit_if_failed($res);
        save_file($dir, $name, $res->content);
        print "Save $dir/$name\n";
    }
}

sub create_gist($$$$$$) {
    my ($token, $desc, $private, $filename, $paths, $embed) = @_;

    my @paths = @$paths;
    my @names = ();
    my @contents = ();
    my $clipboard = Gtk2::Clipboard->get(Gtk2::Gdk->SELECTION_CLIPBOARD);
    if (defined $filename) {
        my $content = $clipboard->wait_for_text;
        usage_and_exit("No content in the clipboard.") if not defined $content;
        push @contents, $content;
        push @names, $filename;
    } elsif (@paths > 0) {
        foreach my $p (@paths) {
            push @contents, load_file($p);
            push @names, File::Basename::basename($p);
        }
    } else {
        usage_and_exit('Both --name and arguments are not found.');
    }

    my $files = {};
    while (@names > 0) {
        my $name = pop @names;
        my $content = pop @contents;
        $files->{$name} = {
            content => $content
        };
    }
    my $input = {};
    $input->{description} = $desc if defined $desc;
    $input->{public} = $private ? JSON::PP::false : JSON::PP::true;
    $input->{files} = $files;
    my $res = http_post("$base_url/gists", $token, encode_json($input));
    exit_if_failed($res);
    my $output = decode_json($res->content);
    my $id = $output->{id};
    print "Gist id: $id\n";
    $clipboard->set_text($embed
        ? q#<script src="https://gist.github.com/$uid/$id.js"></script>#
        : $id);
    $clipboard->store;
}

sub clone_gist($$$) {
    my ($token, $id, $dir) = @_;

    usage_and_exit("--id <id> is required.") if not defined $id;
    File::Path::mkpath($dir);
    debug ("mkdir -p '$dir' && cd '$dir' && git clone http://gist.github.com/$id.git");
    system("mkdir -p '$dir' && cd '$dir' && git clone http://gist.github.com/$id.git");
}

sub delete_gist($$) {
    my ($token, $id) = @_;

    usage_and_exit("--id <id> is required.") if not defined $id;
    my $res = http_delete("$base_url/gists/$id", $token);
    exit_if_failed($res);
}



my %opts = (
    dir => '.',
);
my $cmd = shift @ARGV;
usage_and_exit("No command specified.") if not defined $cmd;
GetOptions(\%opts,
    'since|s=s',
    'id|i=i',
    'uid|u=s',
    'dir|d=s',
    'desc=s',
    'private=s',
    'filename|f=s',
    'embed|e',
    'verbose|v') or usage_and_exit(undef);
$verbose = $opts{verbose};
if ($cmd eq 'login') {
    login();
    exit 0;
}

my $token = load_token();
if ($cmd eq 'list') {
    list_gists($token, $opts{uid}, $opts{since});
} elsif ($cmd eq 'get') {
    get_gist($token, $opts{id}, $opts{dir});
} elsif ($cmd eq 'create') {
    create_gist($token, $opts{desc}, $opts{private}, $opts{filename}, \@ARGV, $opts{embed});
} elsif ($cmd eq 'clone') {
    clone_gist($token, $opts{id}, $opts{dir})
} elsif ($cmd eq 'delete') {
    delete_gist($token, $opts{id});
} else {
    print "unknown command $cmd";
    exit 2;
}
