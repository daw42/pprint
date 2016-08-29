fs = require('fs')
{ exec, execSync } = require('child_process')
path = require('path')

module.exports = Printer =

  printFrameId: '---print-iframe---'
  pygmentsPath: 'pygmentize'

  printContentOnLoad: () ->
    iframe = document.getElementById(@printFrameId)
    ifWin = iframe.contentWindow
    cssPath = atom.packages.resolvePackagePath('pprint')
    cssPath = path.join( cssPath, 'styles', 'print.css')

    printCss = fs.readFileSync( cssPath )
    element = ifWin.document.createElement('style')
    element.setAttribute('type', 'text/css')
    element.textContent = printCss
    ifWin.document.head.appendChild( element )

    mediaQueryList = ifWin.matchMedia('print')
    mediaQueryList.addListener (mql) => @cleanup() if (!mql.matches)

    ifWin.onbeforeunload = @cleanup
    ifWin.print()

  createIframe: () ->
    hiddPrintFrame = document.createElement("iframe")
    hiddPrintFrame.id = @printFrameId
    hiddPrintFrame.style.visibility = "hidden"
    hiddPrintFrame.style.position = "fixed"
    hiddPrintFrame.style.right = "0"
    hiddPrintFrame.style.bottom = "0"
    document.body.appendChild(hiddPrintFrame);
    hiddPrintFrame

  printPage: (html) ->
    hiddPrintFrame = document.getElementById(@printFrameId)
    if( hiddPrintFrame == null )
      hiddPrintFrame = @createIframe()
    hiddPrintFrame.onload = () => @printContentOnLoad()
    hiddPrintFrame.srcdoc = html

  escapePre: ( s ) ->
    s.replace(/&/g, "&amp;").replace(/</g, "&lt;");

  printRaw: ( content ) ->
    html = "<html><body><pre>#{@escapePre(content)}</pre></body></html>"
    @printPage(html)

  checkPygments: () ->
    search = ["pygmentize", path.join("C:\\", "Python27", "Scripts", "pygmentize")]
    found = false
    for exePath in search
      try
        execSync( "#{exePath} -N test.java" )
        found = true
        @pygmentsPath = exePath
      catch err
        # Empty

    return found

  printPygmentsLexer: ( txt, lexer ) ->
    args = atom.config.get('pprint.pygmentsOptions')
    args = "-O #{args} -O full,encoding=utf-8 -f html -l #{lexer}"
    child = exec("#{@pygmentsPath} #{args}", (error, stdout, stderr) =>
      if (error)
        console.error("exec error: #{error}")
        return
      @printPage(stdout)
    )
    child.stdin.write( txt )
    child.stdin.end()

  printPygments: ( txt, fileName ) ->
    # Try to determine the appropriate lexer
    exec("#{@pygmentsPath} -N " + fileName, (error, stdout, sterr) =>
      if(error)
        @printPygmentsLexer(txt, "text");
      else
        @printPygmentsLexer(txt, stdout.trim())
    )

  print: () ->
    editor = atom.workspace.getActiveTextEditor()
    content = editor.getText()
    if @checkPygments()
      @printPygments(content, editor.getTitle())
    else
      @printRaw(content)

  cleanup:  () ->
    document.body.removeChild(document.getElementById(@printFrameId))
