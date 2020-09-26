# frozen_string_literal: true

# name: discourse-debtcollective-sso
# about: Extensions to Discourse SSO provider to work the way we need
# version: 1.0.0
# authors: @debtcollective

def load_plugin
  %w[
    ../lib/engine.rb
    ../config/routes.rb
    ../lib/sso.rb
    ../lib/current_user_provider.rb
    ../lib/algolia_places_client.rb
    ../lib/custom_wizard.rb
    ../lib/extensions/session_controller.rb
    ../lib/extensions/users_controller.rb
    ../lib/extensions/users/omniauth_callbacks_controller.rb
    ../lib/services/base_service.rb
    ../lib/services/user_profile_service.rb
    ../app/jobs/extend_user_profile.rb
    ../app/controllers/collectives_controller.rb
  ].each do |path|
    load File.expand_path(path, __FILE__)
  end
end

def custom_wizard_init
  # welcome wizard step handler
  # we only process the 'debt_types' step
  ::CustomWizard::Builder.add_step_handler('welcome') do |builder|
    current_step = builder.updater.step
    updater = builder.updater
    wizard = builder.wizard
    user = wizard.user

    if current_step.id == "debt_types"
      # fields returns an ActiveParams object
      # we cast it as hash
      step_data = updater.fields.to_h

      groups = step_data.slice(*Debtcollective::CustomWizard.collectives)
      groups_to_join = groups.select { |key, value| groups[key] == true }

      if groups_to_join.any?
        Debtcollective::CustomWizard.add_user_to_groups(user, groups)

        if groups_to_join.include?('solidarity_bloc')
          Debtcollective::CustomWizard.send_solidarity_pm(user)
        end
      end
    end
  end
end

def collectives_init
  Category.register_custom_field_type("tdc_is_collective", :boolean)
  Site.preloaded_category_custom_fields << "tdc_is_collective" if Site.respond_to? :preloaded_category_custom_fields

  add_to_serializer(:basic_category, :tdc_is_collective) do
    !!object.custom_fields["tdc_is_collective"]
  end

  add_to_serializer(:basic_category, :tdc_collective_group) do
    object.groups.where.not(id: Group::AUTO_GROUPS.values).first
  end
end

after_initialize do
  if SiteSetting.enable_debtcollective_sso
    load_plugin()
    collectives_init()

    custom_wizard_init() if Module.const_defined?(:CustomWizard)

    Discourse.current_user_provider = Debtcollective::CurrentUserProvider

    DiscourseEvent.on(:user_created) do |user|
      Jobs.enqueue(:extend_user_profile, { user_id: user.id })
    end
  end
end
