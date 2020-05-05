# frozen_string_literal: true
Discourse::Application.routes.append do
  get "session/sso_cookies/signup" => "session#sso_cookies_signup"
  get "session/sso_cookies" => "session#sso_cookies"
end

::DebtcollectiveSso::Engine.routes.draw do
  get "/login" => "sessions#login"
  get "/signup" => "sessions#signup"
end

Discourse::Application.routes.append do
  mount ::DebtcollectiveSso::Engine, at: '/'
end
