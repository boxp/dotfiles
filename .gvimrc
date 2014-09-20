set vb t_vb=

" フォント
if (hostname() == "Ooedo" || hostname() == "Grimoire")
  set guifont =Ricty\ 10
endif
if (hostname() == "BOXP-PC")
  set guifont=MeiryoKe_Console:h10
endif

"GUI settings
set guioptions-=T "ツールバーなし
set guioptions-=r "右スクロールバーなし
set guioptions-=R
set guioptions-=l "左スクロールバーなし
set guioptions-=L
set guioptions-=b "下スクロールバーなし
set guioptions-=m "メニューバー無し

" fullscreen
"-----------------------------------------------------------
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
