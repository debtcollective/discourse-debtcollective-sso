# frozen_string_literal: true
module DebtcollectiveSso
  class SessionsController < ApplicationController
    skip_before_action :check_xhr, :preload_json, :redirect_to_login_if_required
    layout 'minimal'

    def login
      binding.pry
      respond_to do |format|
        format.html
      end
    end
  end
end
