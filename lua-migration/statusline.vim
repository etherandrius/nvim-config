function! StatusGeneratedFile()
    let path = expand('%:h')
    if path =~ 'generated'
        return '[G]'
    endif
    return ''
endfunction

function! StatusFugitiveDiffFile()
    let path = expand('%:h')
    if path =~ 'fugitive://'
        return '[Diff]'
    endif
    return ''
endfunction

function! StatusJavaPath()
    let path = expand('%:h')
    if path =~ 'java/com/palantir/'
        let path = substitute(path, "java/com/palantir/", "J/", "")
    endif
    if path =~ '/generated/'
        let path = substitute(path, "/generated/", "/G/", "")
    endif
    if path =~ '/src/test/'
        let path = substitute(path, "/src/test/", "/T/", "")
    endif
    if path =~ '/src/main/'
        let path = substitute(path, "/src/main/", "/S/", "")
    endif
    return path
endfunction

