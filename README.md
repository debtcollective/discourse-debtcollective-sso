# discourse-debtcollective-sso

This plugin implements our flavor of SSO for Discourse. We use cookie based authentication across subdomains instead of creating sessions between apps. This provides a better experience and fixes auth of sync sessions between Discourse and other apps.

We are keeping the code from the Discourse SSO provider with our extensions, this is for backwards compatibility with our current tools application. We should remove this once we phase out our current tools.

## Usage

This plugins exposes two endpoints.

1. GET `/session/sso_cookies?return_url=example.com` used for login
1. GET `/session/sso_cookies/signup?return_url=example.com` used for signup

`return_url` is a required param. If it's missing, it will return 400

To login or signup, other applications will redirect to either of these endpoints, and once the login or the signup is completed, it will redirect back to that URL with the SSO cookie set. Then other applications of the same domain will read the SSO cookie that contains a JWT with the user information.

In development, you will need to run the Discourse server with some special configuration

```bash
env DISCOURSE_ENABLE_CORS=true DISCOURSE_DEV_HOST=lvh.me DISCOURSE_SSO_JWT_SECRET=jwt-secret rails s
```

- `DISCOURSE_ENABLE_CORS=true` allow other apps to make CORS request to Discourse. We use this to be able to logout users from other apps
- `DISCOURSE_DEV_HOST=lvh.me` use a custom domain to make cookies to work. `lvh.me` redirects all traffic to 127.0.0.1
- `DISCOURSE_SSO_JWT_SECRET=jwt-secret` this is encryption key for the the JWT cookie. Use the same value between applications

In envs different than development, these variables will be set in the configuration file.
