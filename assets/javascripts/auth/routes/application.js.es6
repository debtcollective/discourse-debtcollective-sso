import Route from '@ember/routing/route'
import { ajax } from 'auth/lib/ajax'

export default Route.extend({
  afterModel() {
    return ajax({
      url: `/site/settings`,
      type: 'GET',
    }).then((result) => {
      $.extend(Auth.SiteSettings, result)
    })
  },
})
