// discourse-skip-module

;(function () {
  if (window.unsupportedBrowser) {
    throw 'Unsupported browser detected'
  }
  window.Discourse = {}
  window.Auth = {}
  Wizard.SiteSettings = {}
  Wizard.RAW_TEMPLATES = {}
  Discourse.__widget_helpers = {}
  window.__DISCOURSE_RAW_TEMPLATES = {}
  Discourse.SiteSettings = Wizard.SiteSettings

  window.AuthApp = requirejs('discourse/auth_app').default.create()

  // required for our template compiler
  window.__DISCOURSE_RAW_TEMPLATES = requirejs(
    'discourse-common/lib/raw-templates'
  ).__DISCOURSE_RAW_TEMPLATES

  // ensure Discourse is added as a global
  window.Discourse = Discourse
})()
