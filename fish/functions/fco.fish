function fco -d 'fzf: checkout git branch or tag'
    argparse -n (status function) 'p/preview' -- $argv
    or return

    set -l tags (git tag | awk '{ print "\x1b[31;1mtag\x1b[m\t" $1; }')
    or return

    set -l branches (git branch --all |
      grep -v HEAD |
      sed -e 's/.* //' -e 's#remotes/[^/]*/##' |
      sort -u |
      awk '{ print "\x1b[34;1mbranch\x1b[m\t" $1; }')
    or return

    set -l target

    set target (string replace -a ' ' '\n' $tags $branches |
      fzf --no-hscroll --ansi +m -d "\t" -n 2 \
        --preview='git log -200 --pretty=format:%s '(echo '{+2..}' | sed 's/\$/../'))
    or return

    git checkout (echo $target | awk '{ print $2; }')
end
