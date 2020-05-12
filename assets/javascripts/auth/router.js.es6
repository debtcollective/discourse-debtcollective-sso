import EmberRouter from '@ember/routing/router'
import getUrl from 'discourse-common/lib/get-url'
import ENV from 'discourse-common/config/environment'

const Router = EmberRouter.extend({
  rootURL: getUrl('/login'),
  location: ENV.environment === 'test' ? 'none' : 'history',
})

Router.map(function () {
  this.route('login')
  this.route('signup')
})

export default Router
