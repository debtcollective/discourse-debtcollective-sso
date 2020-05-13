import { buildResolver } from 'discourse-common/resolver'
import Application from '@ember/application'
import { registerHelpers } from 'discourse-common/lib/helpers'

export default Application.extend({
  rootElement: '#auth',
  Resolver: buildResolver('auth'),

  start() {
    /**
     * This is a workaround for make buildResolver work as expected
     * Discourse buildResolver function expectes to the path of the files to be in the Discourse folder
     * and not in plugins folder. This makes an alias to instead of having
     * discourse/plugins/discourse-debtcollective-sso/auth/router we just have auth/router.
     */
    const pluginPathRegex = /discourse\/plugins\/discourse-debtcollective-sso\/(.*)/
    Object.keys(requirejs._eak_seen).forEach((key) => {
      const matches = key.match(pluginPathRegex)
      if (matches) {
        const shortKey = matches[1]
        requirejs._eak_seen[shortKey] = requirejs._eak_seen[key]
      }

      if (/\/initializers\//.test(key)) {
        const module = requirejs(key, null, null, true)
        if (!module) {
          throw new Error(key + ' must export an initializer.')
        }
        this.initializer(module.default)
      }
    })

    this._initSettings()
    this._loadHelpers()
  },

  // this code was in initializers/load-helpers.js
  // but helpers are loaded with Discourse for some reason and not isolated when the plugin is required
  // and this causes issues with the main Discourse app
  _loadHelpers() {
    Object.keys(requirejs.entries).forEach((entry) => {
      if (/\/helpers\//.test(entry)) {
        requirejs(entry, null, null, true)
      }
    })

    registerHelpers(this)
  },

  _initSettings() {
    this.register('site-settings:main', Auth.SiteSettings, {
      instantiate: false,
    })
  },
})
