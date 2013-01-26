""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"""""""""""""""""""""""""""""""""BOXP vimrc"""""""""""""""""""""""""""""""""""""""
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" キーマップ的な何か
inoremap <C-@> <C-[>
inoremap <C-h> <Home>
nnoremap <C-h> <Home>
inoremap <C-e> <End>
imap <C-k>     <Plug>(neosnippet_expand_or_jump)
smap <C-k>     <Plug>(neosnippet_expand_or_jump)
inoremap <S-Space> <C-[>
nnoremap <Space>w <C-w>
nnoremap r. :<C-u>source ~/Dropbox/dotfiles/.vimrc<CR>
nnoremap su :<C-u>e sudo:%<CR>
" YankRing
nnoremap yr :<C-u>YRShow<CR>
" vimfiler
nnoremap vf :<C-u>VimFilerCurrentDir<CR>
nnoremap vfs :<C-u>VimFilerSplit<CR>
nnoremap vt  :<C-u>VimFilerTab<CR>
nnoremap vi :<C-u>VimFiler -split -simple -winwidth=35 -no-quit<CR>
" Vim-latex
nnoremap ttea :<C-u>TTemplate article<CR>
" Unite
nnoremap uf :<C-u>Unite file<CR>
nnoremap ub :<C-u>Unite buffer<CR>
nnoremap <Space>ub :<C-u>Unite bookmark<CR>
nnoremap ur :<C-u>Unite file_mru<CR>
nnoremap ua :<C-u>Unite file buffer file_mru<CR>
nnoremap ut :<C-u>Unite tweetvim<CR>
nnoremap up :<C-u>Unite mpc:playlist2<CR>
nnoremap um :<C-u>Unite mpc:listall2<CR>
nnoremap ud :<C-u>Unite mpc:ls<CR>
"インサートモードで開始
let g:unite_enable_start_insert = 1
" Execute help.
nnoremap <silent> <C-h>  :<C-u>Unite -buffer-name=help help<CR>
" Vimplenote
nnoremap vnl :<C-u>VimpleNote -l<CR>tiyotiyouda@gmail.com<CR>
nnoremap vnn :<C-u>VimpleNote -n<CR>tiyotiyouda@gmail.com<CR>
" w3m
nnoremap gks :<C-u>W3mSplit google 

" パス設定
let $PATH = $PATH . ':~/bin:~/MaTX/bin:/opt/android-sdk/platform-tools'

""マウス機能有効化
"set mouse=a

""行番号を表示
set number

"autoload設定
"function! s:load_optional_rtp(loc)
"  let loc = expand(a:loc)
"  exe "set rtp+=".loc
"  let files = split(globpath(loc, '**/*.vim'), "\n")
"  for i in reverse(filter(files, 'filereadable(v:val)'))
"    if i !~ '/tests\?/'
"     source `=i`
"   endif
" endfor
"endfunction
"call s:load_optional_rtp("~/Dropbox/.vim/bundle/eskk.vim/autoload/eskk.vim")


" インクリメンタル検索を有効化
set incsearch

" 補完時の一覧表示機能有効化
set wildmenu wildmode=list:full

" 自動的にファイルを読み込むパスを設定 ~/.vim/userautoload/*vim
set runtimepath+=~/.vim/
runtime! userautoload/*.vim

" neocomplcache設定
let g:neocomplcache_enable_at_startup = 1

" Bundleの設定
set nocompatible               " be iMproved

if has('vim_starting')
	set runtimepath+=~/.vim/bundle/neobundle.vim/
	call neobundle#rc(expand('~/.vim/bundle/'))
endif

NeoBundle "mattn/vimplenote-vim"
NeoBundle "mattn/webapi-vim"
NeoBundle "mattn/mkdpreview-vim"
NeoBundle "Shougo/neocomplcache"
NeoBundle "Shougo/unite.vim"
NeoBundle "Shougo/vimfiler"
NeoBundle "Shougo/vimshell"
NeoBundle "danchoi/vmail"
NeoBundle "Solarized"
NeoBundle 'Shougo/vimproc'
NeoBundle 'sudo.vim'
NeoBundle 'Shougo/neobundle.vim'
NeoBundle 'Shougo/echodoc'
NeoBundle 'koron/chalice'
NeoBundle 'micheljansen/vim-latex'
NeoBundle 'yuratomo/w3m.vim'
NeoBundle 'YankRing.vim'
NeoBundle 'tyru/open-browser.vim'
NeoBundle 'basyura/twibill.vim'
NeoBundle 'h1mesuke/unite-outline'
NeoBundle 'basyura/bitly.vim'
NeoBundle 'basyura/TweetVim'
NeoBundle 'mfumi/unite-mpc'
NeoBundle 'mfumi/mpc.vim'
NeoBundle 'jimsei/winresizer'
NeoBundle 'ujihisa/blogger.vim'
NeoBundle 'tpope/vim-pathogen'
NeoBundle 'thinca/vim-quickrun'
NeoBundle 'thinca/vim-logcat'
NeoBundle 'ujihisa/vimshell-ssh'
NeoBundle 'Markdown'
NeoBundle 'scala.vim'
NeoBundle 'derekwyatt/vim-scala'
NeoBundle 'kakkyz81/evervim'
NeoBundle 'textutil.vim'
NeoBundle 'mattn/zencoding-vim'
NeoBundle 'Smooth-Scroll'
NeoBundle 'nathanaelkane/vim-indent-guides'
NeoBundle 'motemen/hatena-vim'
NeoBundle 'tyru/eskk.vim'
NeoBundle 'gre/play2vim'
NeoBundle 'taglist.vim'
NeoBundle 'Shougo/neosnippet'
NeoBundle 'osyo-manga/unite-quickfix'

" vimshell setting
 let g:vimshell_interactive_update_tiME = 10
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
let g:tweetvim_tweet_per_page = 50
" ツイートする度に自動更新
augroup tweetvim_group
    autocmd!
	autocmd BufEnter \[tweetvim\] :TweetVimHomeTimeline
augroup END

"16色に設定
set t_Co=16

" スクリーン名のキャッシュを利用して、neocomplcache で補完する
if !exists('g:neocomplcache_dictionary_filetype_lists')
  let g:neocomplcache_dictionary_filetype_lists = {}
endif
let neco_dic = g:neocomplcache_dictionary_filetype_lists
let neco_dic.tweetvim_say = $HOME . '/.tweetvim/screen_name'

" pathogen設定
call pathogen#infect()
syntax on
filetype plugin indent on

" solarized設定
"let g:solarized_termtrans=1
 syntax enable
" 輝度を高くする
" let g:solarized_visibility = "high"
" コントラストを高くする
" let g:solarized_contrast = "high"
 set background=dark
 colorscheme solarized
" カレント行ハイライトON
set cursorline
" アンダーラインを引く(color terminal)
highlight CursorLine cterm=underline ctermfg=NONE ctermbg=NONE
" アンダーラインを引く(gui)
highlight CursorLine gui=underline guifg=NONE guibg=NONE

" vimfiler
let g:vimfiler_safe_mode_by_default = 0
let g:vimfiler_as_default_explorer = 1

" yank to clipboard
set clipboard+=unnamedplus

" ステータスライン
set laststatus=2   " Always show the statusline

" Vim-LaTeX
filetype plugin on
filetype indent on
set shellslash
set grepprg=grep\ -nH\ $*
let g:tex_flavor='latex'
let g:Imap_UsePlaceHolders = 1
let g:Imap_DeleteEmptyPlaceHolders = 1
let g:Imap_StickyPlaceHolders = 0
let g:Tex_DefaultTargetFormat = 'pdf'
let g:Tex_FormatDependency_ps = 'dvi,ps'
let g:Tex_FormatDependency_pdf = 'dvi,pdf'
let g:Tex_CompileRule_dvi = 'platex -interaction=nonstopmode $*'
"let g:Tex_CompileRule_dvi = 'uplatex -synctex=1 -interaction=nonstopmode $*'
let g:Tex_CompileRule_ps = 'dvips -Ppdf -t a4 -o $*.ps $*.dvi'
let g:Tex_CompileRule_pdf = 'dvipdfmx $*.dvi'
let g:Tex_BibtexFlavor = 'pbibtex'
"let g:Tex_BibtexFlavor = 'upbibtex'
let g:Tex_MakeIndexFlavor = 'mendex $*.idx'
let g:Tex_UseEditorSettingInDVIViewer = 1
let g:Tex_ViewRule_dvi = 'xdvi'
"let g:Tex_ViewRule_dvi = 'advi -watch-file 1'
"let g:Tex_ViewRule_dvi = 'evince'
"let g:Tex_ViewRule_dvi = 'okular --unique'
"let g:Tex_ViewRule_dvi = 'wine ~/.wine/drive_c/w32tex/dviout/dviout.exe -1'
let g:Tex_ViewRule_ps = 'gv --watch'
"let g:Tex_ViewRule_ps = 'evince'
"let g:Tex_ViewRule_ps = 'okular --unique'
"let g:Tex_ViewRule_ps = 'zathura'
let g:Tex_ViewRule_pdf = 'xpdf'
"let g:Tex_ViewRule_pdf = 'gv --watch'
"let g:Tex_ViewRule_pdf = 'evince'
"let g:Tex_ViewRule_pdf = 'okular --unique'
"let g:Tex_ViewRule_pdf = 'zathura'

" Chalice設定
set fencs=usc-bom,usc-21e,usc-2,iso-2022-jp-3,utf-8
set fencs+=cp932
" Chalice用設定
 let chalice_threadlist_lines = 22
 let chalice_preview = 0
 let chalice_titlestring = "Chalice"

 " 板デフォルトの名無しさんを使用
 let chalice_anonyname = ''
 let chalice_threadinfo = 1
 let chalice_foldmarks = '○●'
 let chalice_statusline = '%c,'

 " 起動時にスレの栞を表示
 let chalice_startupflags = 'bookmark'

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

"smooth scroll
:map <C-U> <C-Y><C-Y><C-Y><C-Y><C-Y><C-Y><C-Y><C-Y><C-Y><C-Y><C-Y><C-Y><C-Y><C-Y><C-Y><C-Y>
:map <C-D> <C-E><C-E><C-E><C-E><C-E><C-E><C-E><C-E><C-E><C-E><C-E><C-E><C-E><C-E><C-E><C-E>

" gvim setting
:set guioptions-=T 

"im_control.vim
" 「日本語入力固定モード」切替キー
inoremap <silent> <C-f> <C-r>=IMState('FixMode')<CR>
" PythonによるIBus制御指定
let IM_CtrlIBusPython = 1

" vim-quickrun設定
let g:quickrun_config = {}
let g:quickrun_config.scala = {'command' : 'scala'}
let g:quickrun_config.c = {
	\ 'cmdopt' : '-lm' }

" スカウター
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

" eskk.vim
let g:eskk#directory = "~/Dropbox/.eskk"
let g:eskk#dictionary = { 'path': "~/Dropbox/.skk-jisyo", 'sorted': 0, 'encoding': 'utf-8', }
let g:eskk#large_dictionary = { 'path': "~/Dropbox/.eskk/SKK-JISYO.L", 'sorted': 1, 'encoding': 'euc-jp', }
set imdisable
" eskk.vim 句読点をカンマ、ピリオドに
function! s:eskk_initial_pre()
let t = eskk#table#new('rom_to_hira*', 'rom_to_hira')
call t.add_map(',', ', ')
call t.add_map('.', '.') 
call eskk#register_mode_table('hira', t)
let t = eskk#table#new('rom_to_kata*', 'rom_to_kata')
call t.add_map(',', ', ')
call t.add_map('.', '.')
call eskk#register_mode_table('kata', t)
endfunction

