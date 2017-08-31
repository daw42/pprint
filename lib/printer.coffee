fs = require('fs')
{ spawn, spawnSync } = require('child_process')
path = require('path')

module.exports = Printer =

  printFrameId: '---print-webview---'
  pygmentsPath: 'pygmentize'

  printContent: () ->
    this.getWebContents().title = "The title"
    this.print()

  createWebviewAndPrint: (html) ->
    hiddPrintFrame = document.getElementById(@printFrameId)
    content = "data:text/html;charset=UTF-8," + encodeURIComponent(html)
    if( hiddPrintFrame == null )
      hiddPrintFrame = document.createElement("webview")
      hiddPrintFrame.id = @printFrameId
      hiddPrintFrame.style.visibility = "hidden"
      hiddPrintFrame.style.position = "fixed"
      hiddPrintFrame.style.right = "0"
      hiddPrintFrame.style.bottom = "0"
      cssPath = atom.packages.resolvePackagePath('pprint')
      cssPath = path.join( cssPath, 'styles', 'print.css')
      printCss = fs.readFileSync( cssPath )
      hiddPrintFrame.src = content
      hiddPrintFrame.insertCSS(printCss)
      document.body.appendChild(hiddPrintFrame)
    else
      hiddPrintFrame.loadURL(content)

    hiddPrintFrame.addEventListener('dom-ready', @printContent, {once: true})

  printPage: (html) ->
    f = @createWebviewAndPrint(html)

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
