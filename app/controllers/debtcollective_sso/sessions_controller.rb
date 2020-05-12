# frozen_string_literal: true
module ::DebtcollectiveSso
  class SessionsController < ApplicationController
    skip_before_action :check_xhr, :preload_json, :redirect_to_login_if_required

    def login
    end

    def signup
    end
  end
end
