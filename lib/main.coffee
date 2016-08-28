{ CompositeDisposable } = require('atom')
Printer = require('./printer')

module.exports = PPrint =

  config:
    pygmentsOptions:
      type: 'string'
      default: "style=bw,linenos=inline"
      description: "Options for Pygments.  Passed via the -O option."
      
  subscriptions: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    # Register command that prints the current buffer
    @subscriptions.add atom.commands.add('atom-workspace',
      { 'pprint:print': () => @print() } )

  deactivate: () ->
    this.subscriptions.dispose();

  serialize: () ->
    return { }

  print: () ->
    Printer.print()
