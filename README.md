# discourse-debtcollective-sso

This plugin implements our flavor of SSO for Discourse. We use cookie based authentication across subdomains instead of creating sessions between apps. This provides a better experience and fixes auth of sync sessions between Discourse and other apps.

## Usage

In development, you will need to run the Discourse server with some special configuration

```bash
env DISCOURSE_ENABLE_CORS=true DISCOURSE_DEV_HOST=lvh.me DISCOURSE_SSO_JWT_SECRET=jwt-secret rails s
```

- `DISCOURSE_ENABLE_CORS=true` allow other apps to make CORS request to Discourse. We use this to be able to logout users from other apps
- `DISCOURSE_DEV_HOST=lvh.me` use a custom domain to make cookies to work. `lvh.me` redirects all traffic to 127.0.0.1
- `DISCOURSE_SSO_JWT_SECRET=jwt-secret` this is encryption key for the the JWT cookie. Use the same value between applications

In envs different than development, these variables will be set in the configuration file.
