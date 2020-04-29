  # frozen_string_literal: true
  class DebtcollectiveSessionController < ::ApplicationController
    skip_before_action :check_xhr, :preload_json, :redirect_to_login_if_required

    def login
      render plain: "login page", status: 200
    end
  end
