plastiq = require 'plastiq'
h = plastiq.html
ace = require 'plastiq-ace-editor'
require 'brace/mode/javascript'
require 'brace/theme/chrome'
_ = require 'underscore'
expect = require 'chai'.expect
router = require 'plastiq-router'

Greenhouse = require './greenhouse'
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
        [
          renderModule (mod)
          [
            dep <- model.container.allDependenciesOf(params.name)
            m = model.container.modules.(dep)
            m
            renderModule (m)
          ]
        ]
    )
  )

renderModule (mod) =
  h '.module' (
    { key = mod.id.toString() }

    if (mod.body :: String)
      [
        h 'input.name' { binding = nameBinding (mod) }
        ace (
          {
            binding = bodyBinding (mod)
            key = 'editor'
            theme = 'chrome'
            mode = 'javascript'
            showGutter = false
            highlightActiveLine = false
          }
          h('pre')
        )
      ]
    else
      h '.name' (mod.name)

    h '.exports' (
      renderExports (mod)
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
    '[function]'
  else if (r.type :: String)
    r
  else if (r == undefined)
    '[undefined]'
  else
    r.toString ()

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
         "  catch (e) { return h('.fail', symbols.fail, e.toString()) }\n" + \
         "  return h('.pass', symbols.pass); }"
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

plastiq.append (document.body, render, model)
