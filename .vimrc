"--------------------------------------------------------------------------------"
"                                BOXP vimrc                                      "
"--------------------------------------------------------------------------------"

set encoding=utf-8
set hidden

" source privacy vars(githubに上げたくないパラメーター達)
if filereadable(expand("~/.pri_vimrc"))
  source ~/.pri_vimrc
endif

" indent settings
filetype plugin indent on

" from http://qiita.com/okamos/items/2259d5c770d51b88d75b
" dein settings {{{
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

" キーマップ的な何か
inoremap <silent> <C-@> <C-[>
inoremap <C-e> <End>
imap <C-k> <Plug>(neosnippet_expand_or_jump)
smap <C-k> <Plug>(neosnippet_expand_or_jump)
nnoremap <silent> r. :<C-u>source ~/dotfiles/.vimrc<CR>
nnoremap <silent> \su :<C-u>e sudo:%<CR>
nmap <F12> yyp<C-a>

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

" vimfiler
autocmd FileType vimfiler nmap <buffer> <CR> <Plug>(vimfiler_expand_or_edit)

nnoremap <silent> <Leader>vf :<C-u>VimFilerCurrentDir<CR>
nnoremap <silent> <Leader>vfs :<C-u>VimFilerSplit<CR>
nnoremap <silent> <Leader>vt  :<C-u>VimFilerTab<CR>
nnoremap <silent> <Leader>vi :<C-u>VimFiler -split -simple -winwidth=35 -no-quit<CR>

" Unite
if dein#tap("unite.vim")
  nmap , [unite]

  nnoremap [unite]f :<C-u>Unite file<CR>
  nnoremap [unite]bf :<C-u>Unite buffer<CR>
  nnoremap [unite]bk :<C-u>Unite bookmark<CR>
  nnoremap [unite]r :<C-u>Unite neomru/file<CR>
  nnoremap [unite]a :<C-u>Unite file buffer file_mru<CR>
  nnoremap [unite]<Tab> :<C-u>Unite tab<CR>
  nnoremap [unite]gi :<C-u>Unite giti<CR>
  nnoremap [unite]gb :<C-u>Unite giti/branch_recent<CR>
  nnoremap [unite]gs :<C-u>Unite giti/status<CR>
  nnoremap [unite]gr :<C-u>Unite grep/git:/ -buffer-name=search-buffer -no-quit<CR>
  " カーソル位置の単語をgrep検索
  nnoremap [unite]cgr :<C-u>Unite grep/git:/ -buffer-name=search-buffer -no-quit<CR><C-R><C-W><CR>
  nnoremap [unite]mp :<C-u>Unite mpc<CR>
  nnoremap [unite]ma :<C-u>Unite mapping<CR>
  nnoremap [unite]o :<C-u>Unite outline<CR>
  nnoremap [unite]sn :<C-u>Unite session/new<CR>
  nnoremap [unite]ss :<C-u>Unite session<CR>
  nnoremap [unite]to :<C-u>Unite todo<CR>
  nnoremap [unite]tw :<C-u>Unite tweetvim<CR>
  nnoremap [unite]ta :<C-u>Unite tweetvim/account<CR>
  nnoremap [unite]ij :<C-u>Unite issue:jira<CR>
  nnoremap [unite]ig :<C-u>Unite issue:github<CR>

  " unite-todo
  let g:unite_todo_data_directory = "~/memo"
  nnoremap <silent> <Leader>t :<C-u>UniteTodoAddSimple<CR>

	" unite-session.
	" Save session automatically.
	let g:unite_source_session_enable_auto_save = 1

  " インサートモードで開始
  let g:unite_enable_start_insert = 1

  " unite grepにhw(highway)を使う
  if executable('hw')
    let g:unite_source_grep_command = 'hw'
    let g:unite_source_grep_default_opts = '--no-group --no-color'
    let g:unite_source_grep_recursive_opt = ''
  endif

  " unite-issue
  " Customize
  let g:unite_source_issue_jira_priority_table = {
        \ 10000: '◡', 1: '⚡', 2: 'ᛏ', 3: '●', 4: '○', 5: '▽' }

  let g:unite_source_issue_jira_status_table = {
        \ 1: 'plan', 3: 'develop', 4: 'reopened', 5: 'resolved', 6: 'closed',
        \ 10000: 'feedback', 10001: 'staged', 10002: 'waiting',
        \ 10003: 'deployed', 10004: 'pending', 10008: 'review' }

  let g:unite_source_issue_jira_type_table = {
        \ 1: 'bug', 2: 'feature', 3: 'task', 4: 'change', 5: 'sub-task',
        \ 6: 'epic', 7: 'story', 8: 'system', 9: 'sub-bug' }
endif

" Tsuquyomi
if dein#tap("tsuquyomi")
  " Enable omni completion
  let g:tsuquyomi_completion_detail = 1
  " Tsuquyomiのエラーチェックを無効化
  let g:tsuquyomi_disable_quickfix = 1
  " pathsに基づいたimport文にする
  let g:tsuquyomi_baseurl_import_path	 = 1

  nnoremap <C-i> :<C-u>TsuImport<CR>

  autocmd FileType typescript setlocal completeopt+=menu,preview
endif

" vim-test
if dein#tap("vim-test")
  " TypeScriptのファイルもJavaScriptとして認識させる
  let test#javascript#minitest#file_pattern = '(/__tests__/.*|(\\.|/)(test))\\.(jsx?|tsx?)$'
endif

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

" マウス機能有効化
set mouse=a

""行番号を表示
set number

" インクリメンタル検索を有効化
set incsearch

" 補完時の一覧表示機能有効化
set wildmenu wildmode=list:full

" 自動的にファイルを読み込むパスを設定 ~/.vim/userautoload/*vim
" set runtimepath+=~/.vim/
" runtime! userautoload/*.vim

"neosnippet設定
" Tell Neosnippet about the other snippets
let g:neosnippet#snippets_directory='~/dotfiles/.mysnippets'

" vimshell setting
let g:vimshell_interactive_update_time = 10
let g:vimshell_prompt = $USERNAME."% "

" vimshell map
nnoremap <silent> <Leader>vs :VimShell<CR>
nnoremap <silent> <Leader>vsc :VimShellCreate<CR>
nnoremap <silent> <Leader>vp :VimShellPop<CR>

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
" set cursorline
autocmd ColorScheme
      \  " アンダーラインを引く(color terminal) ※このままではcolorschemeに上書きされる
      \  highlight CursorLine cterm=underline ctermfg=NONE ctermbg=NONE
      \  " アンダーラインを引く(gui)
      \  highlight CursorLine gui=underline guifg=NONE guibg=NONE

" vimfiler
let g:vimfiler_safe_mode_by_default = 0
let g:vimfiler_as_default_explorer = 1

" yank to clipboard
set clipboard=unnamed,unnamedplus,autoselect

" ステータスライン
set laststatus=2   " Always show the statusline

set encoding=utf-8
set fileencodings=utf-8,euc-jp,sjis,iso-2022-jp
set fileformats=unix,dos,mac

"CD
au   BufEnter *   execute ":lcd " . expand("%:p:h")

" backspace
set backspace=indent,eol,start

" vim-python setting
autocmd FileType python set omnifunc=pythoncomplete#Complete

" disable buzzer
set visualbell t_vb=

augroup clojure
  autocmd!
  autocmd FileType clojure call niji#highlight()
  autocmd FileType lisp call niji#highlight()
augroup END

" cljs設定
" augroup cljs
"   autocmd!
"   autocmd BufRead,BufNewFile *.cljs set filetype=clojure
" augroup END

"cljx設定
augroup cljx
  autocmd!
  autocmd BufRead,BufNewFile *.cljx set filetype=clojure
augroup END

"edn設定
augroup edn
  autocmd!
  autocmd BufRead,BufNewFile *.edn set filetype=clojure
augroup END

" matx
autocmd BufRead,BufNewFile *.mm set filetype=C

" fxml
autocmd BufRead,BufNewFile *.fxml set filetype=xml

" xmobarrc
autocmd BufRead,BufNewFile *.xmobarrc set filetype=haskell

" nginx
autocmd BufRead,BufNewFile */nginx/*.conf set filetype=nginx

" graphql
autocmd BufRead,BufNewFile *.graphql set filetype=graphql

" gauche
augroup gauche_autocmd
  au BufRead,BufNewFile *.scm vmap <CR> <Plug>(gosh_repl_send_block)
augroup END

" vim-fireplace
" autocmd BufRead,BufNewFile *.clj,*.cljs,*.cljc vmap <CR> :<C-u>'<,'>Eval<CR>
" autocmd BufRead,BufNewFile *.clj,*.cljs,*.cljc nmap \e :<C-u>Eval<CR>
" autocmd BufRead,BufNewFile *.clj,*.cljs,*.cljc nmap \r :<C-u>Eval (user/reset)<CR>

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

" deoplete
let g:deoplete#enable_at_startup = 1

" Tabbing setting
augroup vimrc
  autocmd! FileType html setlocal expandtab shiftwidth=2 tabstop=2 softtabstop=2
  autocmd! FileType javascript setlocal expandtab shiftwidth=4 tabstop=4 softtabstop=4
  autocmd! FileType json setlocal expandtab shiftwidth=2 tabstop=2 softtabstop=2
  autocmd! FileType css setlocal expandtab shiftwidth=4 tabstop=4 softtabstop=4
  autocmd! FileType scss setlocal expandtab shiftwidth=2 tabstop=2 softtabstop=2
  autocmd! FileType riot setlocal expandtab shiftwidth=4 tabstop=4 softtabstop=4
  autocmd! FileType haskell setlocal expandtab shiftwidth=2 tabstop=2 softtabstop=2
  autocmd! FileType typescript setlocal expandtab shiftwidth=2 tabstop=2 softtabstop=2
  autocmd! FileType vim setlocal expandtab shiftwidth=2 tabstop=2 softtabstop=2
  autocmd! FileType yaml setlocal expandtab shiftwidth=2 tabstop=2 softtabstop=2
  autocmd! FileType ruby setlocal expandtab shiftwidth=2 tabstop=2 softtabstop=2
  autocmd! FileType sql setlocal expandtab shiftwidth=4 tabstop=4 softtabstop=4
augroup END

" watchdogs
let g:watchdogs_check_BufWritePost_enables = {
      \	"scss" : 1,
      \	"textlint" : 1,
      \	"typescript" : 0
      \}

if !exists("g:quickrun_config")
  let g:quickrun_config = {}
endif
" quickfixウィンドウを表示しない
let g:quickrun_config["watchdogs_checker/_"] = {
      \ "outputter/quickfix/open_cmd" : "",
      \ }
let g:quickrun_config["watchdogs_checker/tslint"] = {
      \ "command" : "tslint",
      \ "cmdopt" : "--type-check"
      \}
let g:quickrun_config["typescript/watchdogs_checker"] = {
      \ "type" : "watchdogs_checker/tslint"
      \}
" watchdogs.vim の設定を追加
call watchdogs#setup(g:quickrun_config)

nnoremap <silent> <leader>wa :WatchdogsRun<CR>

" previm
augroup PrevimSettings
  autocmd!
  autocmd BufNewFile,BufRead *.{md,mdwn,mkd,mkdn,mark*} set filetype=markdown
augroup END

" vim-markdown
let g:markdown_fenced_languages = ['vim', 'python', 'ruby', 'clojure', 'cpp', 'bash=sh', 'json=javascript']

" lightline.vim
set laststatus=2
set noshowmode

let g:lightline = {
      \ 'colorscheme': 'solarized',
      \ 'mode_map': { 'c': 'NORMAL' },
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ], [ 'filename' ] ]
      \ },
      \ 'component_function': {
      \   'modified': 'LightLineModified',
      \   'readonly': 'LightLineReadonly',
      \   'filename': 'LightLineFilename',
      \   'fileformat': 'LightLineFileformat',
      \   'filetype': 'LightLineFiletype',
      \   'fileencoding': 'LightLineFileencoding',
      \   'mode': 'LightLineMode',
      \ },
      \ 'separator': { 'left': '', 'right': '' },
      \ 'subseparator': { 'left': '|', 'right': '|' }
      \ }

function! LightLineModified()
  return &ft =~ 'help\|vimfiler\|gundo' ? '' : &modified ? '+' : &modifiable ? '' : '-'
endfunction

function! LightLineReadonly()
  return &ft !~? 'help\|vimfiler\|gundo' && &readonly ? '' : ''
endfunction

function! LightLineFilename()
  return ('' != LightLineReadonly() ? LightLineReadonly() . ' ' : '') .
        \ (&ft == 'vimfiler' ? vimfiler#get_status_string() :
        \  &ft == 'unite' ? unite#get_status_string() :
        \  &ft == 'vimshell' ? vimshell#get_status_string() :
        \ '' != expand('%:t') ? expand('%:t') : '[No Name]') .
        \ ('' != LightLineModified() ? ' ' . LightLineModified() : '')
endfunction

function! LightLineFileformat()
  return winwidth(0) > 70 ? &fileformat : ''
endfunction

function! LightLineFiletype()
  return winwidth(0) > 70 ? (&filetype !=# '' ? &filetype : 'no ft') : ''
endfunction

function! LightLineFileencoding()
  return winwidth(0) > 70 ? (&fenc !=# '' ? &fenc : &enc) : ''
endfunction

function! LightLineMode()
  return winwidth(0) > 60 ? lightline#mode() : ''
endfunction

" indentLine
let g:indentLine_color_term = 239
let g:indentLine_enabled = 1

" TypeScript
let g:js_indent_typescript = 1

" autoformat
" augroup autoformat_autocmd
"   autocmd!
"   au FileType *.ts,*.tsx,*.scss,*.html,*.css  nnoremap <Leader>f :<C-u>Prettier<CR>
"   au BufWrite *.ts,*.tsx,*.scss,*.css :Prettier
" augroup END

let g:autoformat_autoindent = 0
let g:autoformat_retab = 0
let g:autoformat_remove_trailing_spaces = 0

" vim-parenmatch
let g:loaded_matchparen = 1

" remove trailing whitespace
autocmd BufWritePre * :%s/\s\+$//ge

" golang
augroup go_autocmd
  autocmd!
  " highlight error
  autocmd FileType go :highlight goErr cterm=bold ctermfg=136
  autocmd FileType go :match goErr /\<err\>/

  " key mapping
  nnoremap <Leader>l :<C-u>GoLint<CR>
  nnoremap <Leader>t :<C-u>GoTest<CR>
augroup END

" vim-go
" let g:go_highlight_types = 1
let g:go_highlight_fields = 1
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_structs = 0
let g:go_highlight_interfaces = 0
let g:go_highlight_operators = 0
let g:go_metalinter_enabled = ['vet', 'golint', 'errcheck']

" tabの可視化
" set list
" set listchars=tab:>_
" highlight SpecialKey ctermfg=239
" highlight SpecialKey ctermbg=none

" vim-json
if dein#tap("vim-json")
  let g:vim_json_syntax_conceal = 0
endif

" 翻訳
noremap <silent> tr :<C-u>ExciteTranslate<CR>

" 透過
highlight Normal ctermbg=none
highlight NonText ctermbg=none
highlight LineNr ctermbg=none
highlight Folded ctermbg=none
highlight EndOfBuffer ctermbg=none

" Ale
if dein#tap("ale")
  let g:ale_completion_enabled = 0
  let g:ale_fix_on_save = 1
  let g:ale_fixers = {
  \   'typescript': ['prettier', 'tslint'],
  \   'css': ['prettier', 'stylelint']
  \}
endif

" vim-iced
if dein#tap("vim-iced")
  let g:iced_enable_default_key_mappings = 1
endif
