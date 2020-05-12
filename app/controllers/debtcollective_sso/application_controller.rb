# frozen_string_literal: true
module ::DebtcollectiveSso
  class ApplicationController < ::ApplicationController
    prepend_view_path(Rails.root.join('plugins', 'discourse-debtcollective-sso', 'app', 'views'))

    layout 'auth'
  end
end
