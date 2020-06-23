# frozen_string_literal: true

# name: discourse-debtcollective-sso
# about: Extensions to Discourse SSO provider to work the way we need
# version: 1.0.0
# authors: @debtcollective

def load_plugin
  %w[
    ../config/routes.rb
    ../lib/sso.rb
    ../lib/current_user_provider.rb
    ../lib/algolia_places_client.rb
    ../lib/extensions/session_controller.rb
    ../lib/extensions/users_controller.rb
    ../lib/extensions/users/omniauth_callbacks_controller.rb
    ../lib/services/base_service.rb
    ../lib/services/user_profile_service.rb
    ../app/jobs/extend_user_profile.rb
  ].each do |path|
    load File.expand_path(path, __FILE__)
  end
end

after_initialize do
  if SiteSetting.enable_debtcollective_sso
    load_plugin()

    Discourse.current_user_provider = Debtcollective::CurrentUserProvider

    DiscourseEvent.on(:user_created) do |user|
      Jobs.enqueue(:extend_user_profile, { user_id: user.id })
    end
  end
end
