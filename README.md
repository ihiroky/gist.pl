gist.pl
=======

Perl script to get/post snippets from/to https://gist.github.com

Usage
---

    No command specified.
    usage: gist.pl <command> [options...] [arguments...]
    
        Gist command line tool which provides for create, delete, get,
        list and clone. It calls https://api.github.com/authorizations
        to create the api access token. The token is added to
        https://github.com/settings/applications and saved to
        "/home/ihiroky/.github/gist.pl.json".
    
    commands and options:
        clone
            Clones a specified gist.
                -i|--id <id> : required
                    The gist id to clone.
                -d|--dir <directory> : optinal
                    A directory to which the gist is cloned to.
                    Default is '.'
        create
            Creates a new gist, which files is specified with arguments
            or the clipboard. An new id of the gist is copied to the
            clipboard.
                --desc <description> : optional
                    A description for the gist.
                --private : optional
                    Creates the gist as private. If not speciied, public.
                -e|--embed : optinal
                    Copies the script tag for embedding to the clipboard
                    instead of the gist id.
                -f|--filename : required if using clipboard for input
                    A file name for a content of the clipboard. The arguments
                    are ignored.
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
