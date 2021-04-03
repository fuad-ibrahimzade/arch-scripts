cd $HOME
sh /usr/local/bin/VBoxClient-all
set -g -x fish_greeting ''
### "vim" as manpager
set -x MANPAGER '/bin/bash -c "vim -MRn -c \"set buftype=nofile showtabline=0 ft=man ts=8 nomod nolist norelativenumber nonu noma\" -c \"normal L\" -c \"nmap q :qa<CR>\"</dev/tty <(col -b)"'

### "nvim" as manpager
# set -x MANPAGER "nvim -c 'set ft=man' -"
#xcompmgr -c -f -n
function xsh
	bass source $HOME/.xsh ';' xsh --d $argv
end
set -gx EDITOR vim
set -gx VISUAL vim
function dd
	sudo /usr/local/bin/dd $argv
end
function speedread
	python -m speedread $argv
end
function pbcopy
	xsel --clipboard --input $argv
end
function pbpaste
	xsel --clipboard --output $argv
end
