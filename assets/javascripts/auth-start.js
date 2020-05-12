// discourse-skip-module
;(function () {
  const Auth = require('discourse/plugins/discourse-debtcollective-sso/auth/auth').default.create()
  Auth.start()
})()
