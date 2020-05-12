import EmberRouter from '@ember/routing/router'
import getUrl from 'discourse-common/lib/get-url'
import ENV from 'discourse-common/config/environment'

const Router = EmberRouter.extend({
  rootURL: getUrl('/login'),
  location: ENV.environment === 'test' ? 'none' : 'history',
})

Router.map(function () {
  this.route('login', { path: '/login' })
  this.route('signup', { path: '/signup' })
  this.route('onboarding', { path: '/onboarding' })
})

export default Router
