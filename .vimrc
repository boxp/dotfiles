"--------------------------------------------------------------------------------"
"                                BOXP vimrc                                      "
"--------------------------------------------------------------------------------"

" Last modified 2014/09/20

set encoding=utf-8

" source privacy vars(githubに上げたくないパラメーター達)
" g:evervim_devtoken, g:mail_address
if filereadable(".pri_vimrc")
  source .pri_vimrc
endif

" NeoBundleの設定
" Note: Skip initialization for vim-tiny or vim-small.
 if !1 | finish | endif

 if has('vim_starting')
   set nocompatible               " Be iMproved

" Required:
   set runtimepath+=~/.vim/bundle/neobundle.vim/
 endif

" Required:
 call neobundle#begin(expand('~/.vim/bundle/'))

" My Bundles here:
" Refer to |:NeoBundle-examples|.
" Note: You don't set neobundle setting in .gvimrc!
NeoBundle 'Shougo/vimproc', {
      \ 'build' : {
      \     'windows' : 'make -f make_mingw32.mak',
      \     'cygwin' : 'make -f make_cygwin.mak',
      \     'mac' : 'make -f make_mac.mak',
      \     'unix' : 'make -f make_unix.mak',
      \    },
      \ }

NeoBundle 'kchmck/vim-coffee-script'
"NeoBundle 'VimClojure'
NeoBundle 'synic.vim'
NeoBundle 'sudo.vim'
NeoBundle 'YankRing.vim'
NeoBundle 'Markdown'
NeoBundle 'textutil.vim'
NeoBundle 'vim-niji'
NeoBundle "mattn/vimplenote-vim"
NeoBundle "mattn/webapi-vim"
NeoBundle "mattn/mkdpreview-vim"
NeoBundle "altercation/vim-colors-solarized"
NeoBundle "Shougo/neocomplete.vim"
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
NeoBundle 'tyru/open-browser.vim'
NeoBundle 'basyura/twibill.vim'
NeoBundle 'tpope/vim-pathogen'
NeoBundle 'thinca/vim-quickrun'
NeoBundle 'thinca/vim-logcat'
NeoBundle 'thinca/vim-ref'
NeoBundle 'thinca/vim-scouter'
NeoBundle 'thinca/vim-threes'
NeoBundle 'ujihisa/vimshell-ssh'
NeoBundle 'osyo-manga/unite-quickfix'
NeoBundle 'kmnk/vim-unite-giti'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'tpope/vim-fireplace'
NeoBundle 'tpope/vim-classpath'
NeoBundle 'guns/vim-clojure-static'
NeoBundle 'kakkyz81/evervim'
NeoBundle 'kannokanno/unite-todo'
NeoBundle 'aharisu/vim_goshrepl'
NeoBundle 'aharisu/vim-gdev'
NeoBundle 'ujihisa/neoclojure.vim'
NeoBundle 'ujihisa/unite-colorscheme'
NeoBundle 'leafgarland/typescript-vim'
NeoBundle 'Quramy/tsuquyomi'
NeoBundle 'fatih/vim-go'
NeoBundle 'vim-scripts/gtags.vim'
NeoBundle 'haya14busa/incsearch.vim'

" メガネケースでの例外設定
if hostname() != 'meganecase'
  NeoBundle 'basyura/bitly.vim'
  NeoBundle 'basyura/TweetVim'
  NeoBundle 'tsukkee/lingr-vim'
  NeoBundle 'motemen/hatena-vim'
  NeoBundle 'ujihisa/blogger.vim'
endif


call neobundle#end()


" キーマップ的な何か
inoremap <silent> <C-@> <C-[>
inoremap <C-e> <End>
imap <C-k> <Plug>(neosnippet_expand_or_jump)
smap <C-k> <Plug>(neosnippet_expand_or_jump)
nnoremap <silent> r. :<C-u>source ~/dotfiles/.vimrc<CR>:<C-u>source ~/.gvimrc<CR>
nnoremap <silent> su :<C-u>e sudo:%<CR>
nmap <F12> yyp<C-a>
nmap <C-J> @a

" incsearch
map /  <Plug>(incsearch-forward)
map ?  <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)

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
nnoremap \<Space> :<C-u>QuickRun -input "input.txt"<CR> " QuickRun with args(input.txt)


let g:quickrun_config = {
\   "_" : {
\       "runner" : "vimproc",
\       "runner/vimproc/updatetime" : 60
\   },
\}

"インサートモードで開始
let g:unite_enable_start_insert = 1

" Execute help.
nnoremap <silent> <C-h>  :<C-u>Unite -buffer-name=help help<CR>

" Vimplenote
" FIXME: feedkeysを用いるべきではない
nnoremap vnl :call feedkeys("\<C-u>VimpleNote -l\<CR>" . g:mail_address . "\<CR>")
nnoremap vnn :call feedkeys("\<C-u>VimpleNote -n\<CR> . g:mail_address . "\<CR>")

" w3m
nnoremap gks :<C-u>W3mSplit google

" マウス機能有効化
set mouse=a

""行番号を表示
set number

" インクリメンタル検索を有効化
set incsearch

" 補完時の一覧表示機能有効化
set wildmenu wildmode=list:full

" 自動的にファイルを読み込むパスを設定 ~/.vim/userautoload/*vim
set runtimepath+=~/.vim/
runtime! userautoload/*.vim

" neocomplcache設定
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

" TweetVim設定
" タイムライン表示
nnoremap <silent> <Space>tf	:<C-u>TweetVimHomeTimeline<CR>
" 発言用バッファを表示する
nnoremap <silent> <Space>tt     :<C-u>TweetVimSay<CR>
" mentions を表示する
nnoremap <silent> <Space>tr	:<C-u>TweetVimMentions<CR>
" アイコン表示
let g:tweetvim_display_icon = 0
" spで開く
let g:tweetvim_open_buffer_cmd = 'split!'
" 1ページあたりの表示ツイート数
let g:tweetvim_tweet_per_page = 100
" 更新キーをマップ ※augroupなし
autocmd FileType tweetvim nmap <buffer> <C-r> <Plug>(tweetvim_action_reload)
autocmd FileType tweetvim imap <buffer> <C-r> <Plug>(tweetvim_action_reload)
"16色に設定
set t_Co=256

" スクリーン名のキャッシュを利用して、neocomplcache で補完する
if !exists('g:neocomplcache_dictionary_filetype_lists')
  let g:neocomplcache_dictionary_filetype_lists = {}
endif
let s:neco_dic = g:neocomplcache_dictionary_filetype_lists
let s:neco_dic.tweetvim_say = $HOME . '/.tweetvim/screen_name'

" solarized設定
"let g:solarized_termtrans=1
syntax enable
" 輝度を高くする
" let g:solarized_visibility = "high"
" コントラストを高くする
" let g:solarized_contrast = "high"
colorscheme solarized
set background=dark
" カレント行ハイライトON
set cursorline
autocmd ColorScheme
  \  " アンダーラインを引く(color terminal) ※このままではcolorschemeに上書きされる
  \  highlight CursorLine cterm=underline ctermfg=NONE ctermbg=NONE
  \  " アンダーラインを引く(gui)
  \  highlight CursorLine gui=underline guifg=NONE guibg=NONE

" vimfiler
let g:vimfiler_safe_mode_by_default = 0
let g:vimfiler_as_default_explorer = 1

" yank to clipboard
set clipboard+=unnamed

" ステータスライン
set laststatus=2   " Always show the statusline

set encoding=utf-8
set fileencodings=iso-2022-jp,euc-jp,sjis,utf-8
set fileformats=unix,dos,mac

"CD
au   BufEnter *   execute ":lcd " . expand("%:p:h")

"im_control.vim
" 「日本語入力固定モード」切替キー
inoremap <silent> <C-f> <C-r>=IMState('FixMode')<CR>
" PythonによるIBus制御指定
let IM_CtrlIBusPython = 1

" vim-quickrun設定
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
filetype plugin indent on

" vim-ref
"webdictサイトの設定
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

"デフォルトサイト
let g:ref_source_webdict_sites.default = 'ej'

"出力に対するフィルタ。最初の数行を削除
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


"cljs設定
autocmd BufRead,BufNewFile *.cljs set filetype=clojure

"cljx設定
autocmd BufRead,BufNewFile *.cljx set filetype=clojure

" matx
autocmd BufRead,BufNewFile *.mm set filetype=C

" fxml
autocmd BufRead,BufNewFile *.fxml set filetype=xml

"neosnippet設定
" Tell Neosnippet about the other snippets
let g:neosnippet#snippets_directory='~/dotfiles/.mysnippets'

" 自動保存
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

" yank limit
let g:yanking_max_element_length = 104857600

" vim-niji
let g:niji_dark_colours = [
    \ [ '81', '#5fd7ff'],
    \ [ '99', '#875fff'],
    \ [ '1',  '#dc322f'],
    \ [ '76', '#5fd700'],
    \ [ '3',  '#b58900'],
    \ [ '2',  '#859900'],
    \ [ '6',  '#2aa198'],
    \ [ '4',  '#268bd2'],
    \ ]


" neocomplete
"Note: This option must set it in .vimrc(_vimrc).  NOT IN .gvimrc(_gvimrc)!
" Disable AutoComplPop.
let g:acp_enableAtStartup = 0
" Use neocomplete.
let g:neocomplete#enable_at_startup = 1
" Use smartcase.
let g:neocomplete#enable_smart_case = 1
" Set minimum syntax keyword length.
let g:neocomplete#sources#syntax#min_keyword_length = 3
let g:neocomplete#lock_buffer_name_pattern = '\*ku\*'

" Define dictionary.
let g:neocomplete#sources#dictionary#dictionaries = {
    \ 'default' : '',
    \ 'vimshell' : $HOME.'/.vimshell_hist',
    \ 'scheme' : $HOME.'/.gosh_completions'
        \ }

" Define keyword.
if !exists('g:neocomplete#keyword_patterns')
    let g:neocomplete#keyword_patterns = {}
endif
let g:neocomplete#keyword_patterns['default'] = '\h\w*'

" Plugin key-mappings.
inoremap <expr><C-g>     neocomplete#undo_completion()
inoremap <expr><C-l>     neocomplete#complete_common_string()

" Recommended key-mappings.
" <CR>: close popup and save indent.
inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
function! s:my_cr_function()
  return (pumvisible() ? "\<C-y>" : "" ) . "\<CR>"
  " For no inserting <CR> key.
  "return pumvisible() ? "\<C-y>" : "\<CR>"
endfunction
" <TAB>: completion.
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
" <C-h>, <BS>: close popup and delete backword char.
inoremap <expr><C-h> neocomplete#smart_close_popup()."\<C-h>"
inoremap <expr><BS> neocomplete#smart_close_popup()."\<C-h>"
" Close popup by <Space>.
"inoremap <expr><Space> pumvisible() ? "\<C-y>" : "\<Space>"

" AutoComplPop like behavior.
"let g:neocomplete#enable_auto_select = 1

" Shell like behavior(not recommended).
"set completeopt+=longest
"let g:neocomplete#enable_auto_select = 1
"let g:neocomplete#disable_auto_complete = 1
"inoremap <expr><TAB>  pumvisible() ? "\<Down>" : "\<C-x>\<C-u>"

" Enable omni completion.
autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags

" Enable heavy omni completion.
if !exists('g:neocomplete#sources#omni#input_patterns')
  let g:neocomplete#sources#omni#input_patterns = {}
endif
"let g:neocomplete#sources#omni#input_patterns.php = '[^. \t]->\h\w*\|\h\w*::'
"let g:neocomplete#sources#omni#input_patterns.c = '[^.[:digit:] *\t]\%(\.\|->\)'
"let g:neocomplete#sources#omni#input_patterns.cpp = '[^.[:digit:] *\t]\%(\.\|->\)\|\h\w*::'


" For perlomni.vim setting.
" https://github.com/c9s/perlomni.vim
let g:neocomplete#sources#omni#input_patterns.perl = '\h\w*->\h\w*\|\h\w*::'

augroup vimrc
	autocmd! FileType html setlocal shiftwidth=2 tabstop=2 softtabstop=2
	autocmd! FileType javascript setlocal shiftwidth=2 tabstop=2 softtabstop=2
	autocmd! FileType css setlocal shiftwidth=2 tabstop=2 softtabstop=2
augroup END
