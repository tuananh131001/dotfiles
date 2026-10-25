function __cached_init --description 'Source cached output of a tool init command, regenerating when the tool binary changes'
    set -l bin (command -s $argv[1]); or return
    set -l real (path resolve $bin)
    set -l cache_dir ~/.cache/fish/init
    set -l cache $cache_dir/$argv[1].fish
    set -l header "# $real "(path mtime $real)
    set -l first
    test -f $cache; and read first <$cache
    if test "$first" != "$header"
        mkdir -p $cache_dir
        begin
            echo $header
            command $argv
        end >$cache.tmp; and mv -f $cache.tmp $cache; or begin
            rm -f $cache.tmp
            command $argv | source
            return
        end
    end
    source $cache
end
