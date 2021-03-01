# frozen_string_literal: true
Discourse::Application.routes.prepend do
  post "u/email-token" => "users#email_token"
  get "session/sso_cookies/signup" => "session#sso_cookies_signup"
  get "session/sso_cookies" => "session#sso_cookies"
end

Debtcollective::Engine.routes.draw do
end

Discourse::Application.routes.append do
  mount Debtcollective::Engine, at: "/"
end
