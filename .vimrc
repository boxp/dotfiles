"--------------------------------------------------------------------------------"
"                                BOXP vimrc                                      "
"--------------------------------------------------------------------------------"

" Last modified 2014/09/20

" source privacy vars(github�ɏグ�����Ȃ��p�����[�^�[�B)
" g:evervim_devtoken, g:mail_address
if filereadable(".pri_vimrc")
  source .pri_vimrc
endif

" NeoBundle�̐ݒ�
set nocompatible               " be iMproved

if has('vim_starting')
	set runtimepath+=~/.vim/bundle/neobundle.vim/ ""FIXME: Tab
	call neobundle#rc(expand('~/.vim/bundle/'))
endif

NeoBundle 'Shougo/vimproc', {
      \ 'build' : {
      \     'windows' : 'make -f make_mingw32.mak',
      \     'cygwin' : 'make -f make_cygwin.mak',
      \     'mac' : 'make -f make_mac.mak',
      \     'unix' : 'make -f make_unix.mak',
      \    },
      \ }
NeoBundle "mattn/vimplenote-vim"
NeoBundle "mattn/webapi-vim"
NeoBundle "mattn/mkdpreview-vim"
NeoBundle "Solarized"
NeoBundle 'synic.vim'
NeoBundle 'sudo.vim'
NeoBundle "Shougo/neocomplcache"
NeoBundle "Shougo/unite.vim"
NeoBundle "Shougo/neomru.vim"
NeoBundle "Shougo/vimshell"
NeoBundle "Shougo/vimfiler"
NeoBundle 'Shougo/neobundle.vim'
NeoBundle 'Shougo/echodoc'
NeoBundle 'Shougo/neosnippet'
NeoBundle 'Shougo/neosnippet-snippets'
NeoBundle 'Shougo/unite-ssh'
NeoBundle 'Shougo/vinarise'
NeoBundle 'Shougo/unite-session'
NeoBundle 'Shougo/unite-outline'
NeoBundle 'Shougo/unite-help'
NeoBundle 'YankRing.vim'
NeoBundle 'tyru/open-browser.vim'
NeoBundle 'basyura/twibill.vim'
NeoBundle 'tpope/vim-pathogen'
NeoBundle 'thinca/vim-quickrun'
NeoBundle 'thinca/vim-logcat'
NeoBundle 'thinca/vim-ref'
NeoBundle 'thinca/vim-scouter'
NeoBundle 'ujihisa/vimshell-ssh'
NeoBundle 'Markdown'
NeoBundle 'textutil.vim'
NeoBundle 'osyo-manga/unite-quickfix'
NeoBundle 'kmnk/vim-unite-giti'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'VimClojure'
NeoBundle 'tpope/vim-fireplace'
NeoBundle 'tpope/vim-classpath'
NeoBundle 'guns/vim-clojure-static'
NeoBundle 'kakkyz81/evervim'
NeoBundle 'kannokanno/unite-todo'
NeoBundle 'aharisu/vim_goshrepl'
NeoBundle 'aharisu/vim-gdev'
NeoBundle 'ujihisa/neoclojure.vim'
NeoBundle 'ujihisa/unite-colorscheme'

" ���K�l�P�[�X�ł̗�O�ݒ�
if hostname() != 'meganecase'
  NeoBundle 'basyura/bitly.vim'
  NeoBundle 'basyura/TweetVim'
  NeoBundle 'tsukkee/lingr-vim'
  NeoBundle 'motemen/hatena-vim'
  NeoBundle 'ujihisa/blogger.vim'
endif

" �L�[�}�b�v�I�ȉ���
inoremap <silent> <C-@> <C-[>
inoremap <C-e> <End>
imap <C-k> <Plug>(neosnippet_expand_or_jump)
smap <C-k> <Plug>(neosnippet_expand_or_jump)
nnoremap <silent> r. :<C-u>source ~/Dropbox/dotfiles/.vimrc<CR>:<C-u>source ~/.gvimrc<CR>
nnoremap <silent> su :<C-u>e sudo:%<CR>
nmap <F12> yyp<C-a>
nmap <C-J> @a

" window mapping
nmap <Space>w <C-w>
nnoremap <silent> <C-w><C-w> :<C-u>q!<CR>
inoremap <silent> <C-w><C-w> <C-[>:<C-u>q!<CR>

" tab mapping
nnoremap <silent> <C-t> :<C-u>tabnew<CR>
nmap <C-Tab> gt
nmap <C-S-Tab> gT
imap <C-Tab> <ESC>gt
imap <C-S-Tab> <ESC>gT
nmap <C-1> :tabfirst
nmap <C-9> :tablast
imap <C-1> <ESC>:tabfirst
imap <C-9> <ESC>:tablast

" YankRing
nnoremap <silent> yr :<C-u>YRShow<CR>

" vimfiler
nnoremap <silent> <Leader>vf :<C-u>VimFilerCurrentDir<CR>
nnoremap <silent> <Leader>vfs :<C-u>VimFilerSplit<CR>
nnoremap <silent> <Leader>vt  :<C-u>VimFilerTab<CR>
nnoremap <silent> <Leader>vi :<C-u>VimFiler -split -simple -winwidth=35 -no-quit<CR>

" Unite
nmap , [unite]

nnoremap [unite]f :<C-u>Unite file<CR>
nnoremap [unite]bf :<C-u>Unite buffer<CR>
nnoremap [unite]bk :<C-u>Unite bookmark<CR>
nnoremap [unite]r :<C-u>Unite file_mru<CR>
nnoremap [unite]a :<C-u>Unite file buffer file_mru<CR>
nnoremap [unite]tt :<C-u>Unite tweetvim<CR>
nnoremap [unite]p :<C-u>Unite mpc:playlist<CR>
nnoremap [unite]m :<C-u>Unite mpc:listall<CR>
nnoremap [unite]d :<C-u>Unite mpc:ls<CR>
nnoremap [unite]o :<C-u>Unite outline<CR>
nnoremap [unite]<Tab> :<C-u>Unite tab<CR>
nnoremap [unite]g :<C-u>Unite giti<CR>
nnoremap [unite]s :<C-u>Unite session<CR>
nnoremap [unite]to :<C-u>Unite todo<CR>
nnoremap <C-\> :<C-u>Unite mapping<CR>

" quickrun
autocmd BufRead,BufNewFile
\  if filereadable("input.txt")
\    nnoremap \<Space> :<C-u>QuickRun -input "input.txt"<CR> " QuickRun with args(input.txt)
\  endif


let g:quickrun_config = {
\   "_" : {
\       "runner" : "vimproc",
\       "runner/vimproc/updatetime" : 60
\   },
\}

"�C���T�[�g���[�h�ŊJ�n
let g:unite_enable_start_insert = 1

" Execute help.
nnoremap <silent> <C-h>  :<C-u>Unite -buffer-name=help help<CR>

" Vimplenote
" FIXME: feedkeys��p����ׂ��ł͂Ȃ�
nnoremap vnl :call feedkeys("\<C-u>VimpleNote -l\<CR>" . g:mail_address . "\<CR>")
nnoremap vnn :call feedkeys("\<C-u>VimpleNote -n\<CR> . g:mail_address . "\<CR>")

" w3m
nnoremap gks :<C-u>W3mSplit google

" �}�E�X�@�\�L����
set mouse=a

""�s�ԍ���\��
set number

" �C���N�������^��������L����
set incsearch

" �⊮���̈ꗗ�\���@�\�L����
set wildmenu wildmode=list:full

" �����I�Ƀt�@�C����ǂݍ��ރp�X��ݒ� ~/.vim/userautoload/*vim
set runtimepath+=~/.vim/
runtime! userautoload/*.vim

" neocomplcache�ݒ�
let g:neocomplcache_enable_at_startup = 1
let g:neocomplcache_dictionary_filetype_lists = {
            \ 'scala' : $HOME.'/Dropbox/dict/scala.dict',
            \ 'java' : $HOME.'/Dropbox/dict/java.dict'
            \ }

" vimshell setting
let g:vimshell_interactive_update_time = 10
let g:vimshell_prompt = $USERNAME."% "

" vimshell map
nnoremap <silent> vs :VimShell<CR>
nnoremap <silent> vsc :VimShellCreate<CR>
nnoremap <silent> vp :VimShellPop<CR>

" TweetVim�ݒ�
" �^�C�����C���\��
nnoremap <silent> <Space>tf	:<C-u>TweetVimHomeTimeline<CR>
" �����p�o�b�t�@��\������
nnoremap <silent> <Space>tt     :<C-u>TweetVimSay<CR>
" mentions ��\������
nnoremap <silent> <Space>tr	:<C-u>TweetVimMentions<CR>
" �A�C�R���\��
let g:tweetvim_display_icon = 0
" sp�ŊJ��
let g:tweetvim_open_buffer_cmd = 'split!'
" 1�y�[�W������̕\���c�C�[�g��
let g:tweetvim_tweet_per_page = 100
" �X�V�L�[���}�b�v ��augroup�Ȃ�
autocmd FileType tweetvim nmap <buffer> <C-r> <Plug>(tweetvim_action_reload)
autocmd FileType tweetvim imap <buffer> <C-r> <Plug>(tweetvim_action_reload)
"16�F�ɐݒ�
set t_Co=256

" �X�N���[�����̃L���b�V���𗘗p���āAneocomplcache �ŕ⊮����
if !exists('g:neocomplcache_dictionary_filetype_lists')
  let g:neocomplcache_dictionary_filetype_lists = {}
endif
let s:neco_dic = g:neocomplcache_dictionary_filetype_lists
let s:neco_dic.tweetvim_say = $HOME . '/.tweetvim/screen_name'

" solarized�ݒ�
"let g:solarized_termtrans=1
syntax enable
" �P�x����������
" let g:solarized_visibility = "high"
" �R���g���X�g����������
" let g:solarized_contrast = "high"
if (hostname() == "Ooedo")
  " �f�X�N�g�b�v�̏ꍇ
  colorscheme synic
else
  colorscheme solarized
  set background=dark
endif
" �J�����g�s�n�C���C�gON
set cursorline
autocmd ColorScheme
  \  " �A���_�[���C��������(color terminal) �����̂܂܂ł�colorscheme�ɏ㏑�������
  \  highlight CursorLine cterm=underline ctermfg=NONE ctermbg=NONE
  \  " �A���_�[���C��������(gui)
  \  highlight CursorLine gui=underline guifg=NONE guibg=NONE

" vimfiler
let g:vimfiler_safe_mode_by_default = 0
let g:vimfiler_as_default_explorer = 1

" yank to clipboard
set clipboard+=unnamed

" �X�e�[�^�X���C��
set laststatus=2   " Always show the statusline

" �����R�[�h�̎����F��
if &encoding !=# 'utf-8'
  set encoding=japan
  set fileencoding=japan
endif
if has('iconv')
  let s:enc_euc = 'euc-jp'
  let s:enc_jis = 'iso-2022-jp'
  " iconv��eucJP-ms�ɑΉ����Ă��邩���`�F�b�N
  if iconv("\x87\x64\x87\x6a", 'cp932', 'eucjp-ms') ==# "\xad\xc5\xad\xcb"
    let s:enc_euc = 'eucjp-ms'
    let s:enc_jis = 'iso-2022-jp-3'
  " iconv��JISX0213�ɑΉ����Ă��邩���`�F�b�N
  elseif iconv("\x87\x64\x87\x6a", 'cp932', 'euc-jisx0213') ==# "\xad\xc5\xad\xcb"
    let s:enc_euc = 'euc-jisx0213'
    let s:enc_jis = 'iso-2022-jp-3'
  endif
  " fileencodings���\�z
  if &encoding ==# 'utf-8'
    let s:fileencodings_default = &fileencodings
    let &fileencodings = s:enc_jis .','. s:enc_euc .',cp932'
    let &fileencodings = &fileencodings .','. s:fileencodings_default
    unlet s:fileencodings_default
  else
    let &fileencodings = &fileencodings .','. s:enc_jis
    set fileencodings+=utf-8,ucs-2le,ucs-2
    if &encoding =~# '^\(euc-jp\|euc-jisx0213\|eucjp-ms\)$'
      set fileencodings+=cp932
      set fileencodings-=euc-jp
      set fileencodings-=euc-jisx0213
      set fileencodings-=eucjp-ms
      let &encoding = s:enc_euc
      let &fileencoding = s:enc_euc
    else
      let &fileencodings = &fileencodings .','. s:enc_euc
    endif
  endif
  " �萔������
  unlet s:enc_euc
  unlet s:enc_jis
endif
" ���{����܂܂Ȃ��ꍇ�� fileencoding �� encoding ���g���悤�ɂ���
if has('autocmd')
  function! AU_ReCheck_FENC()
    if &fileencoding =~# 'iso-2022-jp' && search("[^\x01-\x7e]", 'n') == 0
      let &fileencoding=&encoding
    endif
  endfunction
  autocmd BufReadPost * call AU_ReCheck_FENC()
endif
" ���s�R�[�h�̎����F��
set fileformats=unix,dos,mac
" ���Ƃ����̕����������Ă��J�[�\���ʒu������Ȃ��悤�ɂ���
if exists('&ambiwidth')
  set ambiwidth=double
endif

"CD
au   BufEnter *   execute ":lcd " . expand("%:p:h")

"im_control.vim
" �u���{����͌Œ胂�[�h�v�ؑփL�[
inoremap <silent> <C-f> <C-r>=IMState('FixMode')<CR>
" Python�ɂ��IBus����w��
let IM_CtrlIBusPython = 1

" vim-quickrun�ݒ�
let g:quickrun_config.scala = {'command' : 'scala'}
let g:quickrun_config.hxml = {'command' : 'haxe'}
let g:quickrun_config.mm = {'command' : 'matx'}
let g:quickrun_config.c = {
	\ 'cmdopt' : '-lm' }

"backspace"
set backspace=indent,eol,start

" vim-python setting
autocmd FileType python set omnifunc=pythoncomplete#Complete

" disable buzzer
set visualbell t_vb=

" haxe settings
if !exists('g:neocomplcache_omni_patterns')
    let g:neocomplcache_omni_patterns = {}
endif
let g:neocomplcache_omni_patterns.haxe = '\v([\]''"]|\w)(\.|\()'

" indent settings
set tabstop=2
set autoindent
set shiftwidth=2
set expandtab

" vim-ref
"webdict�T�C�g�̐ݒ�
let g:ref_source_webdict_sites = {
\   'je': {
\     'url': 'http://dictionary.infoseek.ne.jp/jeword/%s',
\   },
\   'ej': {
\     'url': 'http://dictionary.infoseek.ne.jp/ejword/%s',
\   },
\   'wiki': {
\     'url': 'http://ja.wikipedia.org/wiki/%s',
\   },
\ }

"�f�t�H���g�T�C�g
let g:ref_source_webdict_sites.default = 'ej'

"�o�͂ɑ΂���t�B���^�B�ŏ��̐��s���폜
function! g:ref_source_webdict_sites.je.filter(output)
  return join(split(a:output, "\n")[15 :], "\n")
endfunction
function! g:ref_source_webdict_sites.ej.filter(output)
  return join(split(a:output, "\n")[15 :], "\n")
endfunction
function! g:ref_source_webdict_sites.wiki.filter(output)
  return join(split(a:output, "\n")[17 :], "\n")
endfunction

nmap <Leader>rj :<C-u>Ref webdict je<Space>
nmap <Leader>re :<C-u>Ref webdict ej<Space>
nmap <Leader>rw :<C-u>Ref webdict wiki<Space>

"Lisp�S�ʂ̐ݒ�
let g:lisp_rainbow=1

"cljs�ݒ�
autocmd BufRead,BufNewFile *.cljs set filetype=clojure

"cljx�ݒ�
autocmd BufRead,BufNewFile *.cljx set filetype=clojure

" matx
autocmd BufRead,BufNewFile *.mm set filetype=C

" fxml
autocmd BufRead,BufNewFile *.fxml set filetype=xml

"neosnippet�ݒ�
" Tell Neosnippet about the other snippets
let g:neosnippet#snippets_directory='~/Dropbox/mysnippets'

" �����ۑ�
function! _CompileTexDocument()
  exe ":!~/Dropbox/bin/texcomp.sh"
endfunction
function! _CompileMarkdown()
  exe ":!markdown " . expand("%:p") . " >> output.html"
endfunction

command! CompileTexDocument call _CompileTexDocument()
command! CompileMarkdown call _CompileMarkdown()

autocmd BufWrite *.tex :CompileTexDocument
autocmd BufWrite *.md :CompileMarkdown

" gauche
vmap <CR> <Plug>(gosh_repl_send_block)

" neoclojure
augroup vimrc-neoclojure
  autocmd!
  autocmd FileType clojure setlocal omnifunc=neoclojure#complete
augroup END

let g:quickrun_config.clojure = {
\       'runner': 'neoclojure',
\       'command': 'dummy',
\       'tempfile': '%{tempname()}.clj'
\ }
