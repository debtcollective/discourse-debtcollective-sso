# frozen_string_literal: true
module DebtcollectiveSso
  module StaticControllerExtensions
  end

  ::StaticController.class_eval do
    prepend DebtcollectiveSso::StaticControllerExtensions
    prepend_view_path(Rails.root.join('plugins', DebtcollectiveSso::PLUGIN_NAME, 'app', 'views'))
  end
end
