import { withPluginApi } from 'discourse/lib/plugin-api'
import LoginRoute from 'discourse/routes/login'
import { defaultHomepage } from 'discourse/lib/utilities'

export default {
  name: 'tdc-login-route',
  initialize() {
    withPluginApi('0.8.9', (api) => {
      LoginRoute.reopen({
        renderTemplate() {
          if (this.siteSettings.enable_login_signup_pages) {
            this.render('tdc-login')
          } else {
            this.render('static')
          }
        },

        beforeModel() {},
      })
    })
  },
}
