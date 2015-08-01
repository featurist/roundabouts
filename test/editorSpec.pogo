expect = require 'chai'.expect
browser = require('browser-monkey')
editor = require('../editor')

window._debug = require('debug')

describe 'roundabouts'

  beforeEach
    div = document.createElement ('div')
    div.className = 'roundabouts'
    document.body.appendChild (div)
    editor.mount (div)

  app = browser.extend {

    createNewModule (name, body) =
      form = this.find('.add-module')
      form.find('input[type=text]').typeIn(name)
      form.find('button').click()
      if (body :: String)
        self.updateModuleBody (name, body)

    updateModuleBody (name, body) =
      self.find(".module[data-module=#(name)] .body").element().then @(el)
        window.ace.edit(el).setValue(body)

    resolveModule (name) =
      self.find(".module[data-module=#(name)] .resolved")
  }

  describe 'creating a module'

    it 'evaluates the module and its dependencies'
      app.createNewModule('x', 'return 123') !
      app.createNewModule('y', 'return x + 1') !
      app.resolveModule('y') !.shouldHave { text = "124" }
