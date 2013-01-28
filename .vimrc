"--------------------------------------------------------------------------------"
"                                BOXP vimrc                                      "
"--------------------------------------------------------------------------------"

" �L�[�}�b�v�I�ȉ���
inoremap <C-@> <C-[>
inoremap <C-h> <Home>
inoremap <C-e> <End>
imap <C-k>	<Plug>(neosnippet_expand_or_jump)
smap <C-k>	<Plug>(neosnippet_expand_or_jump)
inoremap <S-Space> <C-[>
nnoremap r. :<C-u>source ~/Dropbox/dotfiles/.vimrc<CR>
nnoremap su :<C-u>e sudo:%<CR>

" window mapping
nmap <Space>w <C-w>
nnoremap <silent> <C-w><C-w> :<C-u>q!<CR>

" tab mapping
nnoremap <silent> <C-t> :<C-u>tabnew<CR>

" YankRing
nnoremap yr :<C-u>YRShow<CR>

" vimfiler
nnoremap vf :<C-u>VimFilerCurrentDir<CR>
nnoremap vfs :<C-u>VimFilerSplit<CR>
nnoremap vt  :<C-u>VimFilerTab<CR>
nnoremap vi :<C-u>VimFiler -split -simple -winwidth=35 -no-quit<CR>

" Unite
nmap , [unite]

nnoremap [unite]f :<C-u>Unite file<CR>
nnoremap [unite]b :<C-u>Unite buffer<CR>
nnoremap [unite]bk :<C-u>Unite bookmark<CR>
nnoremap [unite]r :<C-u>Unite file_mru<CR>
nnoremap [unite]a :<C-u>Unite file buffer file_mru<CR>
nnoremap [unite]t :<C-u>Unite tweetvim<CR>
nnoremap [unite]p :<C-u>Unite mpc:playlist2<CR>
nnoremap [unite]m :<C-u>Unite mpc:listall2<CR>
nnoremap [unite]d :<C-u>Unite mpc:ls<CR>
nnoremap [unite]o :<C-u>Unite outline<CR>
nnoremap [unite]g :<C-u>Unite tab<CR>

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

""�}�E�X�@�\�L����
"set mouse=a

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

" NeoBundle�̐ݒ�
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
NeoBundle 'yuratomo/w3m.vim'
NeoBundle 'YankRing.vim'
NeoBundle 'tyru/open-browser.vim'
NeoBundle 'basyura/twibill.vim'
NeoBundle 'h1mesuke/unite-outline'
NeoBundle 'basyura/bitly.vim'
NeoBundle 'basyura/TweetVim'
NeoBundle 'mfumi/unite-mpc'
NeoBundle 'mfumi/mpc.vim'
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
NeoBundle 'Smooth-Scroll'
NeoBundle 'nathanaelkane/vim-indent-guides'
NeoBundle 'motemen/hatena-vim'
NeoBundle 'gre/play2vim'
NeoBundle 'taglist.vim'
NeoBundle 'Shougo/neosnippet'
NeoBundle 'osyo-manga/unite-quickfix'
NeoBundle 'tsukkee/lingr-vim'
NeoBundle 'tsukkee/unite-help'

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
let g:tweetvim_tweet_per_page = 20

"16�F�ɐݒ�
set t_Co=16

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
 set background=dark
 colorscheme solarized
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
set clipboard+=unnamedplus

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

" gvim setting
:set guioptions-=T 

"im_control.vim
" �u���{����͌Œ胂�[�h�v�ؑփL�[
inoremap <silent> <C-f> <C-r>=IMState('FixMode')<CR>
" Python�ɂ��IBus����w��
let IM_CtrlIBusPython = 1

" vim-quickrun�ݒ�
let g:quickrun_config = {}
let g:quickrun_config.scala = {'command' : 'scala'}
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
