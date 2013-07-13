gist.pl
=======

Perl script to get/post snippets from/to https://gist.github.com


TODO
---

Write how to store the api token.


Usage
---

    gist.pl <command> [options...] [arguments...]
    commands and options:
        clone
            Clones a specified gist.
                -d|--dir <directory> : optinal
        create
            Creates a new gist, which files is specified with arguments.
                --desc <description> : optional
                    A description for the gist.
                --private : optional
                    Creates the gist as private. If not speciied, the gist gets public.
                -f|--filename : required if using clipboard
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
            Lists my gists.
                -s|--since <YYYY-MM-DDTHH:MM:SSZ> : optinal
                    Lists gists updated at or after this time are returned.
