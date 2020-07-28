function! slim#app#init()
    tabe editor
    nnoremap <leader>q :tabc<CR>
    nnoremap <leader>l :call slim#app#requestChannelHistory(g:current_workspace_channel)<CR>:checktime<CR>
    nnoremap <leader>b <c-w>l<c-w>jA
    nnoremap <leader>c <c-w>h<c-w>j/

    if empty(g:current_workspace)
        let g:current_workspace = keys(g:id_map.slim_workspace)[0]
        call slim#util#updateConfig('', {"g:current_workspace": g:current_workspace})
    endif
    if empty(g:current_workspace_channel)
        let g:current_workspace_channel = keys(g:id_map.slim_channel)[0]
        call slim#util#updateConfig('', {"g:current_workspace_channel": g:current_workspace_channel})
    endif
    " Split open our windows and arrange them
    call s:openEditor(g:current_workspace, g:current_workspace_channel)
    call s:openChannel(g:current_workspace, g:current_workspace_channel)
    call s:openChannelList(g:current_workspace)
    execute "normal! \<c-w>H"
    vertical resize 30
    call s:openWorkspaceList()
    resize 12
    execute "normal! \<c-w>l"
    execute "normal! \<c-w>j"
    resize 8 
    " call s:StartListening(g:current_workspace, g:current_workspace_channel)
endfunction

function! s:openEditor(workspace, channel)
    execute 'e '.fnameescape(g:data_path 
        \ .'/workspaces/'
        \ .a:workspace
        \ .'/channels/'
        \ .a:channel
        \ .'.slime')
    inoremap <buffer> <ESC> <ESC>:w<CR>
    nnoremap <buffer> <leader>w ggVG"md:call slim#app#sendMessage(@m, '')<CR>:w<CR><c-w>kj<c-w>j
endfunction

function! s:openChannelList(workspace)
    execute 'sp '.fnameescape(g:data_path 
        \ .'/workspaces/'
        \ . a:workspace
        \ .'/channel.slimc')
    " XXX
    " echo 'openChannelList'
    nnoremap <buffer> slm 0wvt[h"zy:call slim#app#markChannelAsRead({'name': @z, 'id': ''})<CR>
    nnoremap <buffer> slu :call slim#app#checkForUnreadChannel()<CR>
    nnoremap <buffer> <CR> 0wvt[h"zy:call slim#app#changeChannel(@z)<CR>
endfunction

function! s:openChannel(workspace, channel)
    execute 'sp '.fnameescape(g:data_path 
        \ .'/workspaces/'
        \ .a:workspace
        \ .'/channels/'
        \ .a:channel
        \ .'.slimv')
    execute 'w'
    " call TailStart()
    " command! -nargs=0 TailStart call tail#start_tail()
    nnoremap <buffer> slu :call slim#app#checkForUnreadMessages()<CR>
endfunction

function! s:openWorkspaceList()
    execute 'sp '.fnameescape(g:data_path 
        \ .'/workspaces/'
        \ .'/workspace.slimc')
    nnoremap <buffer> <CR> 0f[2lvt]h"wy:call slim#app#changeWorkspace(@w)<CR>
    call s:loadWorkspaceMappings()
endfunction

function! slim#app#sendMessage(text, channel)
    let l:uri = 'https://slack.com/api/chat.postMessage'

    " let l:channel = ""
    if empty(a:channel)
        let l:hi = expand('%:t')
        let l:channel_name = matchstr(expand('%:t'),'.*\ze\.')
        let l:channel = g:id_map['slim_channel'][l:channel_name]
    else
        let l:channel = g:id_map['slim_channel'][a:channel]
    endif

    let l:request = {
        \ 'method': 'POST',
        \ 'uri': l:uri,
        \ 'params': {
        \   "token": get(g:id_map.slim_workspace,g:current_workspace),
        \   "text": "" . a:text,
        \   'channel': l:channel
        \   }
        \ }
    let l:curl = slim#util#getCurlCommand(l:request)
    let l:response = system(l:curl)
    let l:decoded = json_decode(l:response)
endfunction

function! slim#app#changeChannel(channel)
    " XXX
    " echo 'changeChannel 1'
    if g:current_workspace_channel ==# a:channel
        return
    endif

    " XXX
    " echo 'changeChannel 2'
    call slim#util#updateConfig('',{'g:current_workspace_channel': a:channel})
    tabclose
    call slim#StartSlack()
    exe "normal! \<c-w>kjk"
    exe "normal! G"
    " exe normal! \<c-w>h"
    " exe normal! /".@z."\<cr>"
endfunction

function! slim#app#changeWorkspace(workspace)
    if g:current_workspace ==# a:workspace
        return
    endif
    call slim#util#updateConfig('',{'g:current_workspace': a:workspace, 'g:current_workspace_channel': ''})
    tabclose
    call slim#StartSlack()
    exe "normal! \<c-w>h\<c-w>k"
    exe "normal! /".@w."\<cr>"
endfunction

function! s:loadWorkspaceMappings()
    let l:workspaces = readfile(g:data_path.'/workspaces/workspace.slimc')
    for l:workspace in l:workspaces
        let l:mapping = matchstr(l:workspace,'^\zs.*\ze\s[\s')
        let l:workspace_name = matchstr(l:workspace,'\[\s\zs.*\ze\s\]')
        if !empty(l:mapping) && !empty(l:workspace_name)
            exe 'nnoremap '.l:mapping.' :call slim#app#changeWorkspace("'.l:workspace_name.'")'.'<CR>'
        endif
    endfor
endfunction

" XXX a new function to check out for unread channel
" • command! SlackUnreadChannel :call slim#app#checkForUnreadChannel()
function! slim#app#checkForUnreadChannel()
    " echom "FETCHING unread channels..."
    let l:url = 'https://slack.com/api/client.counts'

    let g:id_map['slim_count'] = {}

    let l:request = {
        \ 'method': 'POST',
        \ 'uri': l:url,
        \ 'params': {
        \   "token": get(g:id_map.slim_workspace,g:current_workspace),
        \   }
        \ }
    let l:curl = slim#util#getCurlCommand(l:request)
    let l:response = system(l:curl)
    let l:decoded = json_decode(l:response)
    let l:lines = []
    let l:channels = l:decoded['channels']
    for l:channel in l:channels
      let l:channel_id = channel['id']
      let g:id_map['slim_count'][l:channel_id] = l:channel
    endfor

    let l:workspace_dir = g:data_path . '/workspaces/' .g:current_workspace
    let l:channel_file_name = l:workspace_dir. '/channel.slimc'
    if !filereadable(l:channel_file_name)
        call writefile([], l:channel_file_name)
    endif
    let l:channel_list = readfile(l:channel_file_name)

    let l:n = len(l:channel_list)
    let l:i = 0
    while l:i < l:n
      let l:line = l:channel_list[i]
      let l:key = matchstr(l:line, '\[=\zs.*\ze=\]')
      let l:name = matchstr(l:line, '[\#\|🔒\|\@]\s\zs.*\ze\s\[=')
      let l:str = matchstr(l:line, '\zs.*=\]\ze')

      if !empty(l:key) && !empty(l:name) && has_key(g:id_map['slim_count'], l:key)
        if g:id_map['slim_count'][l:key]['has_unreads']
          let l:channel_list[i] = '' . l:str . ' unread'
        else
          let l:channel_list[i] = '' . l:str
        endif
      endif

      let l:i += 1
    endwhile

    call writefile(l:channel_list, l:channel_file_name)
    execute 'e ' . l:channel_file_name
    " echom "FETCHED unread channels..."
endfunction

" XXX a new function to check out for all unread messages
" • command! SlackUnreadMessages :call slim#app#checkForUnreadMessages()
function! slim#app#checkForUnreadMessages()
    " echom "FETCHING unread messages..."
    let l:url = 'https://slack.com/api/unread.history'

    let l:request = {
        \ 'method': 'POST',
        \ 'uri': l:url,
        \ 'params': {
        \   "token": get(g:id_map.slim_workspace,g:current_workspace),
        \   "timestamp": 0,
        \   "sort": 'newest',
        \   }
        \ }
    let l:curl = slim#util#getCurlCommand(l:request)
    let l:response = system(l:curl)
    let l:decoded = json_decode(l:response)
    let l:lines = []
    let l:channels = l:decoded['channels']

    let l:workspace_dir = g:data_path . '/workspaces/' . g:current_workspace
    let l:channel_file_name = l:workspace_dir . '/all_unreads.slimv'
    if !filereadable(l:channel_file_name)
        call writefile([], l:channel_file_name)
    endif

    let l:lines = []
    for l:channel in l:channels
      let l:count = l:channel['messages_count']
      let l:unreads = l:channel['total_unreads']
      let l:channel_name = get(g:id_map.slack_channel, l:channel.channel_id, 'Channel')
      let l:messages_lines = []
      let l:msg_count = len(l:channel.messages)

      call add(l:lines, l:channel_name . ' (' . l:msg_count . ') [=' . l:channel.channel_id . '=]')
      call add(l:lines, '=======')
      call add(l:lines, '')

      let l:messages = reverse(l:channel['messages'])
      for l:message in l:messages
        let l:user_id = ''
        let l:thread = ' '

        if has_key(l:message, 'reply_count')
          let l:thread = ' (' . l:message.reply_count . ')'
          let l:thread = l:thread . ' [='. l:channel.channel_id .'=]'
          let l:thread = l:thread . ' [='. l:message.thread_ts .'=]'
        endif

        if has_key(l:message, 'user')
          let l:user_id = l:message.user
        elseif has_key(l:message, 'username')
          " prob a named bot
          let l:user_id = l:message.username
        elseif has_key(l:message, 'bot_id')
          let l:user_id = l:message.bot_id
        else
          let l:user_id = 'NONE'
        endif

        let l:user_name = get(g:id_map.slack_member, l:user_id, l:user_id)

        let l:text = map(split(l:message.text, '\n'), '"  ".v:val')
        let l:time = strftime("d-%Ya%mm%dd %I:%M %p", l:message.ts)
        call add(l:messages_lines, l:user_name . ' ' . l:time . l:thread)
        call add(l:messages_lines, '-------')
        call extend(l:messages_lines, l:text)
        call add(l:messages_lines, '')
      endfor
      call extend(l:lines, l:messages_lines)
      call add(l:lines, '')
    endfor

    call writefile(l:lines, l:channel_file_name)
    execute 'e ' . l:channel_file_name
    nnoremap <buffer> slm 0f=lvt="zy:call slim#app#markChannelAsRead({'name': '', 'id': @z})<CR>
    nnoremap <buffer> slu :call slim#app#checkForUnreadMessages()<CR>
    " echom "FETCHED unread messages..."
endfunction

function! slim#app#markChannelAsRead(channel)
    " XXX
    let l:channel_id = a:channel.id
    if has_key(g:id_map['slim_channel'], a:channel.name)
      let l:channel_id = g:id_map['slim_channel'][a:channel.name]
    endif
    if empty(l:channel_id)
      return
    endif

    let l:channel = {}
    if has_key(g:id_map, 'slim_count') && has_key(g:id_map['slim_count'], l:channel_id)
      let l:channel = g:id_map['slim_count'][l:channel_id]
    endif
    if empty(l:channel)
      echom "check for unread channels first, by typing `slu`"
      return
    endif

    let l:url = 'https://slack.com/api/conversations.mark'
    let l:request = {
        \ 'method': 'POST',
        \ 'uri': l:url,
        \ 'params': {
        \   "token": get(g:id_map.slim_workspace,g:current_workspace),
        \   "channel": l:channel_id,
        \   "ts": l:channel.latest,
        \   }
        \ }
    let l:curl = slim#util#getCurlCommand(l:request)
    let l:response = system(l:curl)
    let l:decoded = json_decode(l:response)
    echom 'marked as read the channel: ' . a:channel.name . '' . a:channel.id
    " echom "l:decoded"
endfunction

function! slim#app#requestChannelHistory(channel_name)
    " echom "REQUESTING HISTORY"
    let l:url = 'https://slack.com/api/conversations.history'

    let l:request = {
        \ 'method': 'GET',
        \ 'uri': l:url,
        \ 'params': {
        \   "token": get(g:id_map.slim_workspace,g:current_workspace),
        \   "channel": get(g:id_map.slim_channel,a:channel_name)
        \   }
        \ }
    let l:curl = slim#util#getCurlCommand(l:request)
    let l:response = system(l:curl)
    let l:decoded = json_decode(l:response)
    let l:lines = []
    let l:messages = reverse(l:decoded['messages'])
    for l:message in l:messages
        let l:user_name = ''
        let l:user_id = ''
        if has_key(l:message, 'user')
          let l:user_name = get(g:id_map.slack_member, l:message.user, 'Member')
          let l:user_id = l:message.user
        elseif has_key(l:message, 'username')
          let l:user_name = get(g:id_map.slack_member, l:message.username, 'Member')
          let l:user_id = l:message.username
        else
          let l:user_name = 'XXX'
          let l:user_id = 'YYY'
        endif

        let l:text = map(split(l:message.text, '\n'), '"  ".v:val')

        " let l:text = ' ' .substitute(l:message.text, '\^@', '\n', 'g')
        let l:time = strftime("d-%Ya%mm%dd %I:%M %p", l:message.ts)

        call add(l:lines, l:user_name . ' ' . l:time . ' [='.l:user_id.'=]')
        call add(l:lines, '-------')
        call extend(l:lines, l:text)
        call add(l:lines, '')
    endfor
    let l:file_path = g:data_path
        \ . '/workspaces/'
        \ . g:current_workspace
        \ . '/channels/'
        \ . a:channel_name.'.slimv'
    call writefile(l:lines, l:file_path)
endfunction
