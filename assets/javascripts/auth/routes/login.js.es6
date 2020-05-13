import Route from '@ember/routing/route'

export default Route.extend({
  model() {
    return { logoUrl: Auth.SiteSettings.site_logo_url }
  },
})
