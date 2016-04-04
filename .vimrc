"--------------------------------------------------------------------------------"
"                                BOXP vimrc                                      "
"--------------------------------------------------------------------------------"

set encoding=utf-8

" source privacy vars(githubに上げたくないパラメーター達)
" g:evervim_devtoken, g:mail_address
if filereadable(".pri_vimrc")
  source .pri_vimrc
endif

" from http://qiita.com/okamos/items/2259d5c770d51b88d75b
" dein settings {{{
if &compatible
  set nocompatible
endif
" dein.vimのディレクトリ
let s:dein_dir = expand('~/.cache/dein')
let s:dein_repo_dir = s:dein_dir . '/repos/github.com/Shougo/dein.vim'

" なければgit clone
if !isdirectory(s:dein_repo_dir)
  execute '!git clone https://github.com/Shougo/dein.vim' s:dein_repo_dir
endif
execute 'set runtimepath^=' . s:dein_repo_dir

" 管理するプラグインを記述したファイル
let s:toml = '~/dotfiles/.dein.toml'
let s:lazy_toml = '~/dotfiles/.dein_lazy.toml'

" 読み込み、キャッシュは :call dein#clear_cache() で消せます
if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)
  call dein#load_toml(s:toml, {'lazy': 0})
  call dein#load_toml(s:lazy_toml, {'lazy': 1})
  call dein#end()
  call dein#save_state()
endif

" vimprocだけは最初にインストールしてほしい
if dein#check_install(['vimproc'])
  call dein#install(['vimproc'])
endif
" その他インストールしていないものはこちらに入れる
if dein#check_install()
  call dein#install()
endif
" }}}

" プラグインロード後の設定
augroup rc_autocmd
  autocmd!
augroup END

call dein#begin(s:dein_dir)

if dein#tap('unite.vim')
  function! s:unite_custom() abort
    call unite#custom#source('file', 'matchers', "matcher_default")
  endfunction

  execute 'autocmd rc_autocmd User' 'dein#source#' . g:dein#name 'call s:unite_custom()'
endif

call dein#end()

" キーマップ的な何か
inoremap <silent> <C-@> <C-[>
inoremap <C-e> <End>
imap <C-k> <Plug>(neosnippet_expand_or_jump)
smap <C-k> <Plug>(neosnippet_expand_or_jump)
nnoremap <silent> r. :<C-u>source ~/dotfiles/.vimrc<CR>
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
nnoremap <silent> <Leader>yr :<C-u>YRShow<CR>

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
nnoremap [unite]r :<C-u>Unite neomru/file<CR>
nnoremap [unite]a :<C-u>Unite file buffer file_mru<CR>
nnoremap [unite]<Tab> :<C-u>Unite tab<CR>
nnoremap [unite]g :<C-u>Unite giti<CR>
nnoremap [unite]m :<C-u>Unite mapping<CR>

" インサートモードで開始
let g:unite_enable_start_insert = 1

" quickrun
nnoremap \<space> :<C-u>QuickRun -input "input.txt"<CR> " QuickRun with args(input.txt)

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

" 文字コードの自動認識
if &encoding !=# 'utf-8'
  set encoding=japan
  set fileencoding=japan
endif
if has('iconv')
  let s:enc_euc = 'euc-jp'
  let s:enc_jis = 'iso-2022-jp'
  " iconvがeucJP-msに対応しているかをチェック
  if iconv("\x87\x64\x87\x6a", 'cp932', 'eucjp-ms') ==# "\xad\xc5\xad\xcb"
    let s:enc_euc = 'eucjp-ms'
    let s:enc_jis = 'iso-2022-jp-3'
  " iconvがJISX0213に対応しているかをチェック
  elseif iconv("\x87\x64\x87\x6a", 'cp932', 'euc-jisx0213') ==# "\xad\xc5\xad\xcb"
    let s:enc_euc = 'euc-jisx0213'
    let s:enc_jis = 'iso-2022-jp-3'
  endif
  " fileencodingsを構築
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
  " 定数を処分
  unlet s:enc_euc
  unlet s:enc_jis
endif
" 日本語を含まない場合は fileencoding に encoding を使うようにする
if has('autocmd')
  function! AU_ReCheck_FENC()
    if &fileencoding =~# 'iso-2022-jp' && search("[^\x01-\x7e]", 'n') == 0
      let &fileencoding=&encoding
    endif
  endfunction
  autocmd BufReadPost * call AU_ReCheck_FENC()
endif
" 改行コードの自動認識
set fileformats=unix,dos,mac
" □とか○の文字があってもカーソル位置がずれないようにする
if exists('&ambiwidth')
  set ambiwidth=double
endif

"CD
au   BufEnter *   execute ":lcd " . expand("%:p:h")

"im_control.vim
" 「日本語入力固定モード」切替キー
inoremap <silent> <C-f> <C-r>=IMState('FixMode')<CR>
" PythonによるIBus制御指定
let IM_CtrlIBusPython = 1

"backspace"
set backspace=indent,eol,start

" vim-python setting
autocmd FileType python set omnifunc=pythoncomplete#Complete

" disable buzzer
set visualbell t_vb=

" indent settings
filetype plugin indent on
augroup vimrc
	autocmd! FileType html setlocal shiftwidth=2 tabstop=2 softtabstop=2
	autocmd! FileType javascript setlocal shiftwidth=2 tabstop=2 softtabstop=2
	autocmd! FileType css setlocal shiftwidth=2 tabstop=2 softtabstop=2
augroup END

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

" typescript

