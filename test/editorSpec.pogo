expect = require 'chai'.expect
browser = require('browser-monkey')
editor = require('../editor')

window._debug = require('debug')

describe 'roundabouts'

  mounted = nil

  before
    div = document.createElement('div')
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

    resolvedModule (name) =
      self.find(".module[data-module=#(name)] .resolved")

    addSuggestedModule (name) =
      self.find("a", { text = "Add Module '#(name)'" }).click()
  }

  describe 'creating a module'

    it 'evaluates the module and its dependencies'
      app.createNewModule('x', 'return 123') !
      app.createNewModule('y', 'return x + 1') !
      app.resolvedModule('y') !.shouldHave { text = "124" }

    it 'resolves unresolved dependencies'
      app.createNewModule('a', 'return b') !
      app.addSuggestedModule 'b' !
      app.resolvedModule('a') !.shouldHave { text = "true" }
