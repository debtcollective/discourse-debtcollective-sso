# frozen_string_literal: true
module DebtcollectiveSso
  class ApplicationController < ::ApplicationController
    before_action :prepend_plugin_view_path

    def prepend_plugin_view_path
      prepend_view_path(Rails.root.join('plugins', 'discourse-debtcollective-sso', 'app', 'views'))
    end
  end
end
