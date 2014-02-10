"--------------------------------------------------------------------------------"
"                                BOXP vimrc                                      "
"--------------------------------------------------------------------------------"

" Last modified 2013/02/27 21:48

" NeoBundle�̐ݒ�
set nocompatible               " be iMproved

if has('vim_starting')
	set runtimepath+=~/.vim/bundle/neobundle.vim/
	call neobundle#rc(expand('~/.vim/bundle/'))
endif

NeoBundle "mattn/vimplenote-vim"
NeoBundle "mattn/webapi-vim"
NeoBundle "mattn/mkdpreview-vim"
NeoBundle "Solarized"
NeoBundle 'synic.vim'
NeoBundle 'sudo.vim'
NeoBundle "Shougo/neocomplcache"
NeoBundle "Shougo/unite.vim"
NeoBundle "Shougo/vimfiler"
NeoBundle "Shougo/vimshell"
NeoBundle 'Shougo/vimproc'
NeoBundle 'Shougo/neobundle.vim'
NeoBundle 'Shougo/echodoc'
NeoBundle 'Shougo/neosnippet'
NeoBundle 'Shougo/unite-ssh'
NeoBundle 'Shougo/vinarise'
NeoBundle 'Shougo/unite-session'
NeoBundle 'YankRing.vim'
NeoBundle 'tyru/open-browser.vim'
NeoBundle 'basyura/twibill.vim'
NeoBundle 'h1mesuke/unite-outline'
NeoBundle 'mfumi/unite-mpc'
NeoBundle 'mfumi/mpc.vim'
NeoBundle 'tpope/vim-pathogen'
NeoBundle 'thinca/vim-quickrun'
NeoBundle 'thinca/vim-logcat'
NeoBundle 'thinca/vim-ref'
NeoBundle 'ujihisa/vimshell-ssh'
NeoBundle 'Markdown'
NeoBundle 'derekwyatt/vim-scala'
NeoBundle 'textutil.vim'
NeoBundle 'gre/play2vim'
NeoBundle 'taglist.vim'
NeoBundle 'osyo-manga/unite-quickfix'
NeoBundle 'tsukkee/unite-help'
NeoBundle 'kmnk/vim-unite-giti'
NeoBundle 'surround.vim'
NeoBundle 'jdonaldson/vaxe'
NeoBundle 'VimIRC.vim'
NeoBundle '2GMon/mikutter_mode.vim'
NeoBundle 'VimClojure'
NeoBundle 'tpope/vim-fireplace'
NeoBundle 'ctford/vim-fireplace-easy'
NeoBundle 'tpope/vim-classpath'
NeoBundle 'guns/vim-clojure-static'
NeoBundle 'kakkyz81/evervim'
NeoBundle 'kannokanno/unite-todo'
NeoBundle 'aharisu/vim_goshrepl'

" ���K�l�P�[�X�ŋN�������Ⴞ�[��
NeoBundleLazy 'basyura/bitly.vim'
NeoBundleLazy 'basyura/TweetVim'
NeoBundleLazy 'tsukkee/lingr-vim'
NeoBundleLazy 'motemen/hatena-vim'
NeoBundleLazy 'yuratomo/w3m.vim'
NeoBundleLazy 'ujihisa/blogger.vim'

if (hostname() != "meganecase")
  NeoBundleSource
endif

" �L�[�}�b�v�I�ȉ���
inoremap <silent> <C-@> <C-[>
inoremap <C-e> <End>
imap <C-k>	<Plug>(neosnippet_expand_or_jump)
smap <C-k>	<Plug>(neosnippet_expand_or_jump)
nnoremap <silent> r. :<C-u>source ~/Dropbox/dotfiles/.vimrc<CR>
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
nnoremap <silent> vf :<C-u>VimFilerCurrentDir<CR>
nnoremap <silent> vfs :<C-u>VimFilerSplit<CR>
nnoremap <silent> vt  :<C-u>VimFilerTab<CR>
nnoremap <silent> vi :<C-u>VimFiler -split -simple -winwidth=35 -no-quit<CR>

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
nnoremap \<Space> :<C-u>QuickRun -input "input.txt"<CR>

" gauche keymap
vmap <CR> <Plug>(gosh_repl_send_block)

"" runner/vimproc/updatetime �ŏo�̓o�b�t�@�̍X�V�Ԋu���~���b�Őݒ�ł��܂�
"" updatetime ���ꎞ�I�ɏ����������Ă��܂��̂Œ��ӂ��ĉ�����
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
nnoremap vnl :<C-u>VimpleNote -l<CR>tiyotiyouda@gmail.com<CR>
nnoremap vnn :<C-u>VimpleNote -n<CR>tiyotiyouda@gmail.com<CR>

" w3m
nnoremap gks :<C-u>W3mSplit google 

" �p�X�ݒ�
let $PATH = $PATH . ':~/bin:~/MaTX/bin:/opt/android-sdk/platform-tools'

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
if has("gui_running")
  let g:NeoComplCache_DictionaryFileTypeLists = {
              \ 'scala' : $HOME.'\Dropbox\dict\scala.dict',
              \ 'java' : $HOME.'\Dropbox\dict\java.dict'
              \ }
else
  let g:NeoComplCache_DictionaryFileTypeLists = {
              \ 'scala' : $HOME.'/Dropbox/dict/scala.dict',
              \ 'java' : $HOME.'/Dropbox/dict/java.dict'
              \ }
endif

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
" �X�V�L�[���}�b�v
autocmd FileType tweetvim nmap <buffer> <C-r> <Plug>(tweetvim_action_reload)
autocmd FileType tweetvim imap <buffer> <C-r> <Plug>(tweetvim_action_reload)
"16�F�ɐݒ�
set t_Co=256
"meganecase�ݒ�
if(hostname() == "meganecase")
   set t_Co=256
endif

" �X�N���[�����̃L���b�V���𗘗p���āAneocomplcache �ŕ⊮����
if !exists('g:neocomplcache_dictionary_filetype_lists')
  let g:neocomplcache_dictionary_filetype_lists = {}
endif
let neco_dic = g:neocomplcache_dictionary_filetype_lists
let neco_dic.tweetvim_say = $HOME . '/.tweetvim/screen_name'

" solarized�ݒ�
"let g:solarized_termtrans=1
 syntax enable
" �P�x����������
" let g:solarized_visibility = "high"
" �R���g���X�g����������
" let g:solarized_contrast = "high"
if (hostname() == "Grimoire" || hostname() == "Ooedo")
  colorscheme synic
endif
if (hostname() == "BOXP-PC")
  set t_Co=16
  set background=dark
  colorscheme solarized
endif
" �J�����g�s�n�C���C�gON
set cursorline
" �A���_�[���C��������(color terminal)
highlight CursorLine cterm=underline ctermfg=NONE ctermbg=NONE
" �A���_�[���C��������(gui)
highlight CursorLine gui=underline guifg=NONE guibg=NONE

" vimfiler
let g:vimfiler_safe_mode_by_default = 0
let g:vimfiler_as_default_explorer = 1

" yank to clipboard
set clipboard+=unnamed

" �X�e�[�^�X���C��
set laststatus=2   " Always show the statusline

" Chalice�ݒ�
set fencs=usc-bom,usc-21e,usc-2,iso-2022-jp-3,utf-8
set fencs+=cp932
" Chalice�p�ݒ�
 let chalice_threadlist_lines = 22
 let chalice_preview = 0
 let chalice_titlestring = "Chalice"

 " �f�t�H���g�̖�����������g�p
 let chalice_anonyname = ''
 let chalice_threadinfo = 1
 let chalice_foldmarks = '����'
 let chalice_statusline = '%c,'

 " �N�����ɃX���̞x��\��
 let chalice_startupflags = 'bookmark'

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
let g:quickrun_config = {}
let g:quickrun_config.scala = {'command' : 'scala'}
let g:quickrun_config.hxml = {'command' : 'haxe'}
let g:quickrun_config.mm = {'command' : 'matx'}
let g:quickrun_config.c = {
	\ 'cmdopt' : '-lm' }

" �X�J�E�^�[
function! Scouter(file, ...)
	let pat = '^\s*$\|^\s*"'
	let lines = readfile(a:file)
	if !a:0 || !a:1
        let lines = split(substitute(join(lines, "\n"), '\n\s*\\', '', 'g'), "\n")
	endif
	return len(filter(lines,'v:val !~ pat'))
endfunction
command! -bar -bang -nargs=? -complete=file Scouter
\ echo Scouter(empty(<q-args>) ? $MYVIMRC : expand(<q-args>), <bang>0)
command! -bar -bang -nargs=? -complete=file GScouter
\ echo Scouter(empty(<q-args>) ? $MYGVIMRC : expand(<q-args>), <bang>0)

"backspace"
set backspace=indent,eol,start

" vim-python setting
autocmd FileType python set omnifunc=pythoncomplete#Complete

" disable buzzer
set visualbell t_vb=

" surround.vim settings
nmap <C-s> ysW"
nmap " cs'"
nmap ' cs"'

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

" GUI font setting
if (has("gui_running") )
  if (hostname() == "Ooedo" || hostname() == "Grimoire")
    set guifont =Ricty\ 10
  endif 
  if (hostname() == "BOXP-PC")
    set guifont=MeiryoKe_Console:h10
  endif
endif

"GUI settings
set guioptions-=T "�c�[���o�[�Ȃ�
set guioptions-=r "�E�X�N���[���o�[�Ȃ�
set guioptions-=R
set guioptions-=l "���X�N���[���o�[�Ȃ�
set guioptions-=L
set guioptions-=b "���X�N���[���o�[�Ȃ�
set guioptions-=m "���j���[�o�[����

" fullscreen
"-----------------------------------------------------------
if (has("gui_running") && (hostname() == "BOXP-PC"))
  nnoremap <F11> :call ToggleFullScreen()<CR>
  function! ToggleFullScreen()
    if &guioptions =~# 'C'
      set guioptions-=C
      if exists('s:go_temp')
        if s:go_temp =~# 'm'
          set guioptions+=m
        endif
        if s:go_temp =~# 'T'
          set guioptions+=T
        endif
      endif
      simalt ~r
    else
      let s:go_temp = &guioptions
      set guioptions+=C
      set guioptions-=m
      set guioptions-=T
      simalt ~x
    endif
  endfunction
endif

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

"cljs�ݒ�
autocmd BufRead,BufNewFile *.cljs set filetype=clojure

" matx
autocmd BufRead,BufNewFile *.mm set filetype=C

" fxml
autocmd BufRead,BufNewFile *.fxml set filetype=xml


"neosnippet�ݒ�
" Tell Neosnippet about the other snippets
let g:neosnippet#snippets_directory='~/Dropbox/mysnippets'

" �����ۑ�
function! _CompileTexDocument()
  :w
  exe ":!~/Dropbox/bin/texcomp.sh"
endfunction
function! _CompileMarkdown()
  :w
  exe ":!markdown *.md > output.html"
endfunction

command! CompileTexDocument call _CompileTexDocument()
command! CompileMarkdown call _CompileMarkdown()

autocmd BufWrite *.{tex} :CompileTexDocument
autocmd BufWrite *.{md} :CompileMarkdown

" evervim
let g:evervim_devtoken='S=s66:U=734804:E=146dbacbe49:C=13f83fb924d:P=1cd:A=en-devtoken:V=2:H=88d428022e1d8c509d6aa1b3e08a33f1'
