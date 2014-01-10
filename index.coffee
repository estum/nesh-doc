colors = require 'colors'
intdoc = require 'intdoc'
vm = require 'vm'

__doc__ = """Shows documentation for an expression; you can also type Ctrl-Q in-line"""

lastTokenPlus = (input) ->
  """A crude cut at figuring out where the last thing you want to 
    evaluate in what you're typing is
    
    Ex. If you are typing
      myVal = new somemodule.SomeClass

    You probably just want help on `somemodule.SomeClass`

    """

  t = ""
  for c in input by -1
    if c not in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.[]'\"$_:"
      break
    t = c + t

  # Trim the string down if there are dots on either end
  if t[0] is "."
    t = t[1..]
  if t[..-2] is "."
    t = t[..-2]

  t


exports.postStart = (context) ->
  {repl} = context

  document = (expr, reportErrors) -> 
    if expr.trim().length == 0
      repl.outputStream.write colors.cyan "#{ __doc__ }\n"
    else
      try 
        if repl.useGlobal
          result = vm.runInThisContext "(#{ expr })"
        else
          result = vm.runInContext "(#{ expr })", repl.context
      catch e
        if reportErrors
          repl.outputStream.write colors.red "Bad input; can't document\n"
        repl.displayPrompt()
        return null

      #repl.outputStream.write "#{ colors.cyan result }\n"

      doc = intdoc result
      if doc.name and doc.name.length > 0
        tyname = "[#{ doc.type }: #{ doc.name }]"
      else
        tyname = "[#{ doc.type }]"
      repl.outputStream.write colors.cyan tyname
      if typeof result is 'function' and doc.params?
        repl.outputStream.write colors.yellow " #{ doc.name }(#{ ("#{ x }" for x in doc.params).join ", "})"
      repl.outputStream.write "\n"
      if doc.doc? and doc.doc.length > 0
        repl.outputStream.write doc.doc + "\n"

      #repl.outputStream.write colors.green result.toString() + "\n"
    repl.displayPrompt()


  repl.defineCommand 'doc',
    help: __doc__
    action: (expr) ->
      document expr, true

  # Add a handler for Ctrl-Q that does documentation for
  # the most recent thing you typed
  repl.inputStream.on 'keypress', (char, key) ->
    return unless key and key.ctrl and not key.meta and not key.shift and key.name is 'q'
    rli = repl.rli
    repl.docRequested = true
    rli.write "\n"

  originalEval = repl.eval
  repl.eval = (input, context, filename, callback) ->
    if repl.docRequested
      repl.docRequested = false
      #console.log colors.green "'#{ input }'"
      input = input[1..-3]
      toDoc = lastTokenPlus input
      if toDoc != input
        repl.outputStream.write colors.yellow toDoc + "\n"
      document toDoc
      repl.rli.write input
    else
      originalEval input, context, filename, callback

#module.exports.lastTokenPlus = lastTokenPlus
