" NOTE: You must, of course, install ag / the_silver_searcher

" Location of the ag utility
if !exists("g:agprg")
  let g:agprg="ag --column"
endif

if !exists("g:ag_apply_qmappings")
  let g:ag_apply_qmappings=1
endif

if !exists("g:ag_apply_lmappings")
  let g:ag_apply_lmappings=1
endif

if !exists("g:ag_qhandler")
  let g:ag_qhandler="botright copen"
endif

if !exists("g:ag_lhandler")
  let g:ag_lhandler="botright lopen"
endif

if !exists("g:ag_mapping_message")
  let g:ag_mapping_message=1
endif

if !exists("g:ag_scm_dirs")
  let g:ag_scm_dirs = [ '.git', '.svn', '.hg' ]
endif

if !exists("g:ag_results_mapping")
  let g:ag_results_mapping = {}
endif

if !has_key(g:ag_results_mapping, 'open_and_close')
  let g:ag_results_mapping['open_and_close'] = 'e'
endif

if !has_key(g:ag_results_mapping, 'open')
  let g:ag_results_mapping['open'] = 'o,<cr>'
endif

if !has_key(g:ag_results_mapping, 'preview_open')
  let g:ag_results_mapping['preview_open'] = 'go'
endif

if !has_key(g:ag_results_mapping, 'new_tab')
  let g:ag_results_mapping['new_tab'] = 't'
endif

if !has_key(g:ag_results_mapping, 'new_tab_silent')
  let g:ag_results_mapping['new_tab_silent'] = 'T'
endif

if !has_key(g:ag_results_mapping, 'horizontal_split')
  let g:ag_results_mapping['horizontal_split'] = 'h'
endif

if !has_key(g:ag_results_mapping, 'horizontal_split_silent')
  let g:ag_results_mapping['horizontal_split_silent'] = 'H'
endif

if !has_key(g:ag_results_mapping, 'vertical_split')
  let g:ag_results_mapping['vertical_split'] = 'v'
endif

if !has_key(g:ag_results_mapping, 'vertical_split_silent')
  let g:ag_results_mapping['vertical_split_silent'] = 'gv'
endif

if !has_key(g:ag_results_mapping, 'quit')
  let g:ag_results_mapping['quit'] = 'q'
endif

function! ag#FindSCMDir()
  let filedir = expand('%:p:h')
  for candidate in g:ag_scm_dirs
    let dir = finddir(candidate, filedir . ';')
    if dir == candidate
      return '.'
    elseif dir != ""
      let dir = substitute(dir, '/' . candidate, '', '')
      return dir
    endif
  endfor
  return "~"
endfunction

function! ag#ApplyMapping(dictkey, mapping)
  for key in split(g:ag_results_mapping[a:dictkey], ',')
    exe "nnoremap <silent> <buffer> " . key . " " . a:mapping
  endfor
endfunction

function! ag#AgForExtension(cmd, opts, regex, ...)
  let exts = []
  " map() is just too much of a pain in the ass
  for e in a:000
    call add(exts, substitute(e, '^\.\=\(.*\)', '\\.\1$', ''))
  endfor
  if empty(exts)
    echoerr "No extensions provided."
  else
    let extRegex = join(exts, '|')
    call ag#Ag(a:cmd, a:regex, extend(a:opts, {'specific_file_exts': extRegex}))
  endif
endfunction

function! ag#Ag(cmd, args, opts)
  let l:ag_args = ""
  
  if empty(a:opts)
    let a:opts = {}
  endif

  " Handle the types of files to search
  if has_key(a:opts, 'current_file_ext')
    let l:ag_args = l:ag_args . " -G'\\." . expand('%:e') . "$'"
  elseif has_key(a:opts, 'specific_file_exts')
    let l:ag_args = l:ag_args . " -G'" . a:opts['specific_file_exts'] . "'"
  endif

  " If no pattern is provided, search for the word under the cursor
  let l:pat = expand('<cword>')
  if !empty(a:args)
    let l:pat = a:args
    let l:pat = substitute(l:pat, '\%(\\<\|\\>\)', '\\b', 'g')
    let l:pat = substitute(l:pat, '\\', '\\\\', 'g')
  endif
  let l:ag_args = l:ag_args . ' ' . l:pat

  " If they want to search from the 'scm' directory
  if has_key(a:opts, 'scmdir')
    let l:ag_args = l:ag_args . ' ' . ag#FindSCMDir()
  elseif has_key(a:opts, 'current_file_dir')
    let l:ag_args = l:ag_args . ' ' . expand('%:p:h')
  elseif has_key(a:opts, 'specific_dirs')
    let l:ag_args = l:ag_args . ' ' . a:opts['specific_dirs']
  endif

  " Format, used to manage column jump
  if a:cmd =~# '-g$'
    let g:agformat="%f"
  elseif !exists("g:agformat")
    let g:agformat="%f:%l:%c:%m"
  endif

  let grepprg_bak=&grepprg
  let grepformat_bak=&grepformat
  try
    let &grepprg=g:agprg
    let &grepformat=g:agformat
    let toExecute = a:cmd . " " . escape(l:ag_args, "|")
    silent execute toExecute
  finally
    let &grepprg=grepprg_bak
    let &grepformat=grepformat_bak
  endtry

  if a:cmd =~# '^l'
    let l:match_count = len(getloclist(winnr()))
  else
    let l:match_count = len(getqflist())
  endif

  if a:cmd =~# '^l' && l:match_count
    exe g:ag_lhandler
    let l:apply_mappings = g:ag_apply_lmappings
    let l:matches_window_prefix = 'l' " we're using the location list
  elseif l:match_count
    exe g:ag_qhandler
    let l:apply_mappings = g:ag_apply_qmappings
    let l:matches_window_prefix = 'c' " we're using the quickfix window
  endif

  " If highlighting is on, highlight the search keyword.
  if exists("g:aghighlight")
    let @/ = l:pat
    set hlsearch
  end

  redraw!

  if l:match_count
    if l:apply_mappings
      call ag#ApplyMapping('horizontal_split', '<C-W><CR><C-w>K')
      call ag#ApplyMapping('horizontal_split_silent', '<C-W><CR><C-w>K<C-w>b')
      call ag#ApplyMapping('open', '<cr>')
      call ag#ApplyMapping('new_tab', '<C-w><CR><C-w>T')
      call ag#ApplyMapping('new_tab_silent', '<C-w><CR><C-w>TgT<C-W><C-W>')
      call ag#ApplyMapping('vertical_split', '<C-w><CR><C-w>H<C-W>b<C-W>J<C-W>t')

      call ag#ApplyMapping('open_and_close', '<CR><C-w><C-w>:' . l:matches_window_prefix . 'close<CR>')
      call ag#ApplyMapping('preview_open', '<CR>:' . l:matches_window_prefix . 'open<CR>')
      call ag#ApplyMapping('quit', ':' . l:matches_window_prefix . 'close<CR>')

      call ag#ApplyMapping('vertical_split_silent', ':let b:height=winheight(0)<CR><C-w><CR><C-w>H:' . l:matches_window_prefix . 'open<CR><C-w>J:exe printf(":normal %d\<lt>c-w>_", b:height)<CR>')
      " Interpretation:
      " :let b:height=winheight(0)<CR>                      Get the height of the quickfix/location list window
      " <CR><C-w>                                           Open the current item in a new split
      " <C-w>H                                              Slam the newly opened window against the left edge
      " :copen<CR> -or- :lopen<CR>                          Open either the quickfix window or the location list (whichever we were using)
      " <C-w>J                                              Slam the quickfix/location list window against the bottom edge
      " :exe printf(":normal %d\<lt>c-w>_", b:height)<CR>   Restore the quickfix/location list window's height from before we opened the match

      if g:ag_mapping_message && l:apply_mappings
        echom "ag.vim keys: " . g:ag_results_mapping['quit'] . "=quit " .
          \   g:ag_results_mapping['open'] . '/' .
          \   g:ag_results_mapping['open_and_close'] . '/' .
          \   g:ag_results_mapping['new_tab'] . '/' .
          \   g:ag_results_mapping['horizontal_split'] . '/' .
          \   g:ag_results_mapping['vertical_split'] . "=enter/edit/tab/split/vsplit " .
          \   g:ag_results_mapping['preview_open'] . '/' .
          \   g:ag_results_mapping['horizontal_split_silent'] . '/' .
          \   g:ag_results_mapping['vertical_split_silent'] . "=preview versions of same"
      endif
    endif
  else
    echom 'No matches for "' . l:pat . '"'
  endif
endfunction

function! ag#AgFromSearch(cmd, opts)
  let search = getreg('/')
  call ag#Ag(a:cmd, search, a:opts)
endfunction

function! ag#GetDocLocations()
  let dp = ''
  for p in split(&runtimepath,',')
    let p = p.'/doc/'
    if isdirectory(p)
      let dp = p.'*.txt '.dp
    endif
  endfor
  return dp
endfunction

function! ag#AgHelp(cmd, args)
  call ag#Ag(a:cmd, a:args, {'specific_dirs': ag#GetDocLocations()})
endfunction
