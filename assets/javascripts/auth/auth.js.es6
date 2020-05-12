import { buildResolver } from 'discourse-common/resolver'
import Application from '@ember/application'

export default Application.extend({
  rootElement: '#auth',
  Resolver: buildResolver('auth'),

  start() {
    console.log('started')
    Object.keys(requirejs._eak_seen).forEach((key) => {
      if (/\/initializers\//.test(key)) {
        const module = requirejs(key, null, null, true)
        if (!module) {
          throw new Error(key + ' must export an initializer.')
        }
        this.initializer(module.default)
      }
    })
  },
})
