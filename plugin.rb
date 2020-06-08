# frozen_string_literal: true

# name: discourse-debtcollective-sso
# about: Extensions to Discourse SSO provider to work the way we need
# version: 1.0.0
# authors: @debtcollective

require 'jwt'

def load_plugin
  %w[
    ../config/routes.rb
    ../lib/sso.rb
    ../lib/current_user_provider.rb
    ../lib/extensions/session_controller.rb
    ../lib/extensions/users_controller.rb
    ../lib/extensions/users/omniauth_callbacks_controller.rb
  ].each do |path|
    load File.expand_path(path, __FILE__)
  end
end

after_initialize do
  if SiteSetting.enable_debtcollective_sso
    load_plugin()

    Discourse.current_user_provider = Debtcollective::CurrentUserProvider
  end
end
