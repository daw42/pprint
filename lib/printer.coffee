fs = require('fs')
{ spawn, spawnSync } = require('child_process')
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
    result = spawnSync( @pygmentsPath, ["-N", "test.java"] )
    (not result.error) and result.status == 0

  printPygmentsLexer: ( txt, lexer ) ->
    args = atom.config.get('pprint.pygmentsOptions')
    args = ["-O", args, "-O", "full,encoding=utf-8", "-f", "html", "-l", lexer]
    child = spawn(@pygmentsPath, args)
    child.stdin.write(txt)
    child.stdin.end()
    data = []
    child.on('error', (err) => console.error( err ))
    child.stdout.on('data', (chunk) => data.push(chunk) )
    child.on('exit', (code, signal) =>
      if code == 0
        @printPage(data.join(""))
      else
        console.error("Failed to execute pygments")
    )

  printPygments: ( txt, fileName ) ->
    # Pygments doesn't handle text files well
    if path.extname(fileName).toLowerCase() == '.txt'
      @printRaw(txt)
      return

    # Try to determine the appropriate lexer
    child = spawn(@pygmentsPath, ["-N", fileName])
    data = []
    child.on('error', (err) => console.error( err ))
    child.stdout.on('data', (chunk) => data.push(chunk) )
    child.on('exit', (code, signal) =>
      if code == 0
        @printPygmentsLexer(txt, data.join("").trim())
      else
        @printPygmentsLexer(txt, "text");
    )

  print: () ->
    editor = atom.workspace.getActiveTextEditor()
    if editor != null
      content = editor.getText()
      if content != null and content.length > 0
        if @checkPygments()
          @printPygments(content, editor.getTitle())
        else
          @printRaw(content)

  cleanup:  () ->
    document.body.removeChild(document.getElementById(@printFrameId))
