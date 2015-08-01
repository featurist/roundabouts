plastiq = require 'plastiq'
h = plastiq.html
ace = require 'plastiq-ace-editor'
require 'brace/mode/javascript'
require 'brace/theme/chrome'
_ = require 'underscore'
expect = require 'chai'.expect
router = require 'plastiq-router'

Greenhouse = require 'greenhouse'
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
          model.container.module { name = model.newModuleName, body = 'return true' }
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
  else if (r.type :: String)
    r
  else if (r == undefined)
    h '.undefined' 'undefined'
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
        model.container.module { name = d, body = 'return true' }
        e.preventDefault()
    } ("Add Module '#(d)'")
  ]

model = { container = container }

window.model = model

container.module {
  name = '$'
  resolved = require 'vdom-query'
}

container.module {
  name = 'exampleReceipt'
  body = "return receipt({ items: [menuItem('beans'), menuItem('toast')] })"
}

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
  name = 'examplePassingDomTest'
  body = "return test(function() {\n" + \
         "  var dom =  $(function() { return exampleReceipt });\n" + \
         "  var total = dom.find('.total').first().text();\n" + \
         "  expect(total).to.equal('TOTAL = 1.90'); })"
}

container.module {
  name = 'exampleFailingTest'
  body = "return test(function() {\n" + \
         "  expect('sausages').to.equal('eggs'); });"
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
  name = 'menuData'
  body = "return [\n" + \
         "  { name: 'toast', price: '0.80' },\n" + \
         "  { name: 'beans', price: '1.10' }\n" + \
         "]"
}

container.module {
  name = 'menuItem'
  body = "return function(name) {\n" + \
         "  return _.findWhere(menuData, { name: name }) }"
}

container.module {
  name = 'receipt'
  body = "return function(order) {\n" + \
         "  return h('.receipt', receiptItems(order), receiptTotal(order)) }"
}

container.module {
  name = 'receiptItems'
  body = "return function(order) {\n" + \
         "  return _.map(order.items, function(item) {\n" + \
         "    return h('.receipt-item', item.name, ' - ', item.price);\n" + \
         "  });\n" + \
         "}"
}

container.module {
  name = 'receiptTotal'
  body = "return function(order) {\n" + \
         "  var total = sum(_.pluck(order.items, 'price')).toFixed(2);\n" + \
         "  return h('.total', 'TOTAL = ' + total)\n" + \
         "}"
}

container.module {
  name = 'reflectionExample'
  body = "return h('ul', greenhouse.moduleNames().map(function(name) {\n" + \
         "  return h('li', name) }));"
}

container.module {
  name = 'findAllTests'
  body = "return greenhouse.moduleNames().filter(function(name) {\n" + \
         "   return greenhouse.dependenciesOf(name).indexOf('test') > -1 });"
}

container.module {
  name = 'h'
  resolved = require 'plastiq'.html
}

container.module {
  name = '_'
  resolved = _
}

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

mount (element) = plastiq.append (element, render, model)

module.exports.mount = mount
