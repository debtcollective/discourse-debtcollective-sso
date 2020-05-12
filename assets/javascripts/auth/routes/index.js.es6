import Route from '@ember/routing/route'

export default Ember.Route.extend({
  beforeModel() {
    console.log('before model')
  },

  model() {
    return { text: 'index route' }
  },
})
