import Application from '@ember/application'

export default Application.extend({
  rootElement: '#auth',

  start() {
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
