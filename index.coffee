__doc__ = """Shows documentation for an expression; you can also type Ctrl-Q in-line"""

crayon = require 'crayon-terminal'
intdoc = require 'intdoc'
{ isFunction } = require 'lodash-node'
vm = require 'vm'

lastTokenPlus = (input) ->
  """A crude cut at figuring out where the last thing you want to
    evaluate in what you're typing is

    Ex. If you are typing
      myVal = new somemodule.SomeClass

    You probably just want help on `somemodule.SomeClass`

    """

  t = ""
  if input?
    for c in input by -1
      if c not in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.[]'\"$_:"
        break
      t = c + t

    # Trim the string down if there are dots on either end
    if t[0] is "."
      t = t[1..]
    if t[-1..] is "."
      t = t[..-2]

  t

exports.__doc__ = __doc__

exports.postStart = (context) ->
  { repl } = context

  _eval = (expr) ->
    try
      if repl.useGlobal
        vm.runInThisContext "(#{ expr })"
      else
        vm.runInContext "(#{ expr })", repl.context
    catch e
      return undefined


  document = (expr, reportErrors, showCode) ->
    if expr.trim().length == 0
      if reportErrors
        repl.outputStream.write crayon.cyan "#{ __doc__ }\n"
    else
      repl.outputStream.write crayon.yellow "#{ expr }\n"
      try
        if repl.useGlobal
          result = vm.runInThisContext "(#{ expr })"
        else
          result = vm.runInContext "(#{ expr })", repl.context
      catch e
        if reportErrors
          repl.outputStream.write crayon.red "Bad input; can't document\n"
        repl.displayPrompt()
        return null

      if result?.that? and isFunction result
        # This is a synchronized version of a fibrous function
        # so we look to the original one instead
        result = result.that
        defibbed = true
      else
        defibbed = false

      doc = intdoc result
      if defibbed
        callbackParam = doc.params.pop()
      if doc.name and doc.name.length > 0
        tyname = "[#{ doc.type }: #{ doc.name }]"
      else
        tyname = "[#{ doc.type }]"
      repl.outputStream.write crayon.cyan tyname
      if typeof result is 'function' and doc.params?
        repl.outputStream.write crayon.yellow " #{ doc.name ? crayon.gray '<Lambda>' }(#{ ("#{ x }" for x in doc.params).join ", "})"
        if defibbed
          repl.outputStream.write crayon.yellow " *#{ callbackParam } handled by fibrous"
      repl.outputStream.write "\n"
      if doc.doc? and doc.doc.length > 0
        repl.outputStream.write doc.doc + "\n"

    if showCode
      if doc
        if doc.code?
          repl.outputStream.write crayon.green doc.code + "\n"
        else
          repl.outputStream.write crayon.green "#{ result }\n"

    repl.displayPrompt()

    # Return the documentation
    doc


  repl.defineCommand 'doc',
    help: __doc__
    action: (expr) ->
      document expr, true

  # Add a handler for Ctrl-Q that does documentation for
  # the most recent thing you typed
  __lastKeypressWasCtrlQ = false
  repl.inputStream.on 'keypress', (char, key) ->
    leave = true unless key and key.ctrl and not key.meta and not key.shift and key.name is 'q'
    if leave
      __lastKeypressWasCtrlQ = false
    else
      rli = repl.rli
      cp = rli.cursor
      origPrompt = repl._prompt ? repl.prompt
      input = rli.line
      rli.output.write "\n"
      toDoc = lastTokenPlus input
      document toDoc, false, __lastKeypressWasCtrlQ
      rli.line = ""
      rli.write input
      __lastKeypressWasCtrlQ = true
