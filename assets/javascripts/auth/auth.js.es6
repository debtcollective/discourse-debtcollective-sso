import { buildResolver } from 'discourse-common/resolver'
import Application from '@ember/application'

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
    })
  },
})
