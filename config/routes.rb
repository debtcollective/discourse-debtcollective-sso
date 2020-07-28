# frozen_string_literal: true
Discourse::Application.routes.append do
  get "session/sso_cookies/signup" => "session#sso_cookies_signup"
  get "session/sso_cookies" => "session#sso_cookies"
end

Debtcollective::Engine.routes.draw do
  put "/collectives/:id/join" => "collectives#join"
end

Discourse::Application.routes.append do
  mount Debtcollective::Engine, at: "/"
end
