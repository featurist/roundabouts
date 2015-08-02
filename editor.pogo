plastiq = require 'plastiq'
h = plastiq.html
ace = require 'plastiq-ace-editor'
require 'brace/mode/javascript'
require 'brace/theme/chrome'
_ = require 'underscore'
expect = require 'chai'.expect
router = require 'plastiq-router'
Greenhouse = require 'greenhouse'

mount (element) = plastiq.append (element, render, model)

exports.mount = mount

container = @new Greenhouse()

routes = {
  root = router.route '/'
  module = router.route '/modules/:name'
}

router.start()

bodyBinding (mod) =
  {
    get () = mod.body

    set (v) =
      mod.body = v
      model.container.module {
        name = mod.name
        body = mod.body
      }
  }

nameBinding (mod) =
  {
    get () = mod.name

    set (v) =
      if (mod.name != v)
        model.container.rename (mod.name, v)
  }

render (model) =
  h '.client' (
    h (
      'form.add-module'
      h 'input' { type = 'text', binding = [model, 'newModuleName'] }
      h 'button' {
        onclick (e) =
          model.container.module { name = model.newModuleName, body = '' }
          routes.module(name: model.newModuleName).push()
          model.newModuleName = ''
          e.preventDefault()

      } 'Add Module'
    )

    h 'ul.modules-menu' (
      [
        moduleName <- model.container.moduleNames()
        mod = model.container.modules.(moduleName)
        mod.body :: String
        h 'li' [
          routes.module { name = moduleName }.a (moduleName)
        ]
      ]
      [
        moduleName <- model.container.moduleNames()
        mod = model.container.modules.(moduleName)
        @not (mod.body :: String)
        h 'li' [
          routes.module { name = moduleName }.a (moduleName)
        ]
      ]
    )

    h '.modules' (
      routes.module @(params)
        mod = model.container.modules.(params.name)
        if (mod)
          [
            renderModule (mod)
            [
              dep <- model.container.eventualDependenciesOf(params.name)
              m = model.container.modules.(dep)
              m
              m != mod
              renderModule (m)
            ]
          ]
        else
          h 'a' {
            href = "##(params.name)"
            onclick (e) =
              model.container.module { name = params.name, body = '' }
              e.preventDefault()
          } "Add Module '#(params.name)'"
    )
  )

renderModule (mod) =
  h '.module' (
    { 'data-module' = mod.name, key = mod.id.toString() }

    if (mod.body :: String)
      [
        h 'input.name' { binding = nameBinding (mod) }
        ace (
          {
            binding = bodyBinding (mod)
            key = 'editor'
            theme = 'chrome'
            mode = 'javascript'
            configure (editor) =
              editor.$blockScrolling = Infinity
              editor.setOptions {
                maxLines = Infinity
                showGutter = false
                highlightActiveLine = false
              }
          }
          h('pre.body')
        )
      ]
    else
      h '.name' (mod.name)

    h '.exports' (
      renderExports (mod)
    )

    h '.unresolved-dependencies' (
      renderUnresolvedDependencies (mod.dependencies)
    )
  )

renderExports (mod) =
  try
    h '.resolved' (
      renderResolved ( model.container.resolve (mod.name) )
    )
  catch (e)
    h('.fail', "ERROR: " + e.toString())

renderResolved (r) =
  if (r :: Function)
    h '.function' 'function'
  else if (r == undefined)
    h '.undefined' 'undefined'
  else if (r.type :: String)
    r
  else if (r :: Array)
    h 'ul.array' [
      n <- r
      h 'li' (renderResolved (n))
    ]
  else if (r :: Error)
    h '.fail' (r)
  else
    s = r.toString ()
    if (s == {}.toString())
      h '.object' 'object'
    else
      h '.string' (r.toString ())

renderUnresolvedDependencies (dependencies) =
  [
    d <- dependencies
    @not model.container.modules.(d)
    h '.action a.unresolved-dependency' {
      href = '#resolve'
      onclick (e) =
        model.container.module { name = d, body = '' }
        e.preventDefault()
    } ("Add Module '#(d)'")
  ]

model = {
  container = container

  commonJsFor (mod) =
    [
      d <- [mod.name].concat (withoutGlobals(
        self.container.eventualDependenciesOf(mod.name)
      ))
      body = self.commonJsBodyFor(self.container.modules.(d))
      deps = withoutGlobals(self.container.dependenciesOf(d))
      "var #(d) = (function(#(deps)){ #(body) })(#(deps));"
    ].reverse().concat [
      "module.exports = #(mod.name);"
    ].join("\n\n")

  commonJsBodyFor (mod) =
    console.log("M", mod)
    if (mod)
      if (mod.package :: String)
        "return require('#(mod.package)');"
      else
        mod.body
    else
      "undefined"
}

withoutGlobals (dependencies) =
  [
    d <- dependencies
    typeof (global.(d)) == 'undefined'
    d
  ]

moduleCommonJs (name) =
  model.commonJsFor (model.container.modules.(name))

window.model = model

container.module {
  name = 'allTests'
  body = "return h('.all-tests', findAllTests.map(function(m) {\n" + \
         "  return h('.test', { style: { padding: '10px' } }, m, resolve(m)) }))"
}

container.module {
  name = 'resolve'
  body = "return function(name) {\n" + \
         "  try { return greenhouse.resolve(name) }\n" + \
         "  catch(e) { return h('.fail', e.toString()) } }"
}

container.module {
  name = 'test'
  body = "return function(fn) {\n" + \
         "  try { fn() }\n" + \
         "  catch (e) { return fail(e.toString()) }\n" + \
         "  return pass(); }"
}

container.module {
  name = 'styles'
  body = "return {\n" + \
         "  pass: { backgroundColor: 'rgb(192, 249, 192)' },\n" + \
         "  fail: { backgroundColor: 'rgb(255, 219, 225)' } }"
}

container.module {
  name = 'pass'
  body = "return function(text) { return outcome('pass', text || 'PASS'); }"
}

container.module {
  name = 'fail'
  body = "return function(text) { return outcome('fail', text); }"
}

container.module {
  name = 'outcome'
  body = "return function(name, text) {\n" + \
          "  return h('.' + name, { style: styles[name] }, symbols[name], text) }"
}

container.module {
  name = 'symbols'
  body = "return { fail: symbol('&#x2715;'), pass: symbol('&#x2713;') }"
}

container.module {
  name = 'symbol'
  body = "return function(html) { return h.rawHtml('.symbol', html) }"
}

container.module {
  name = 'symbolTable'
  body = "return h('.symbols', Object.keys(symbols).map(function(key) {\n" + \
         "  return h('.symbol', symbols[key], key); }));"
}

container.module {
  name = 'sum'
  body = "return function(items) {\n" + \
         "  return _.reduce(items, function(memo, num){\n" + \
         "    return memo + Number(num); }, 0); }"
}

container.module {
  name = 'findAllTests'
  body = "return greenhouse.moduleNames().filter(function(name) {\n" + \
         "   return greenhouse.dependenciesOf(name).indexOf('test') > -1 });"
}

container.module {
  name = 'demoVideo'
  body = "return h('iframe', {\n" + \
         "  style: { margin: '10px 0' },\n" + \
         "  width: '500',\n" + \
         "  height: '370',\n" + \
         "  attributes: { allowfullscreen: 'allowfullscreen', frameborder: 'no' },\n" + \
         "  src: 'https://www.youtube.com/embed/47Kdhp7hs_c' });"
}

container.module {
  name = 'plastiq'
  resolved = require 'plastiq'
}

container.module {
  name = 'h'
  body = 'return plastiq.html'
}

container.module {
  name = '_'
  resolved = _
}

container.modules._.package = 'underscore'

container.module {
  name = 'Number'
  resolved = Number
}

container.module {
  name = 'Object'
  resolved = Object
}

container.module {
  name = 'Error'
  resolved = Error
}

container.module {
  name = 'JSON'
  resolved = JSON
}

container.module {
  name = 'expect'
  resolved = expect
}

container.module {
  name = 'greenhouse'
  resolved = container
}

container.module {
  name = '$'
  resolved = require 'vdom-query'
}

container.module {
  name = 'commonjs'
  resolved = moduleCommonJs
}
