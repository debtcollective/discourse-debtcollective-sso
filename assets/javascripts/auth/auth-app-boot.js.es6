// discourse-skip-module

;(function () {
  if (window.unsupportedBrowser) {
    throw 'Unsupported browser detected'
  }

  // create and start authapp
  window.AuthApp = requirejs(
    'discourse/plugins/discourse-debtcollective-sso/assets/auth/auth_app'
  ).default.create()

  window.AuthApp.start()
})()
