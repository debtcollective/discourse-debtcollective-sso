# frozen_string_literal: true

# name: discourse-debtcollective-sso
# about: Extensions to Discourse SSO provider to work the way we need
# version: 0.0.2
# authors: @debtcollective

require 'jwt'

after_initialize do
  load File.expand_path('../lib/sso.rb', __FILE__)
  load File.expand_path('../lib/current_user_provider.rb', __FILE__)

  module DebtCollectiveSessionController
    def sso_provider(payload = nil)
      redirect_to path('/login')
    end

    def sso_provider_signup
      redirect_to path('/signup')
    end

    private

    def check_return_url
      return_url = params[:return_url]

      if return_url.blank?
        render plain: "redirect_url is blank, it must be provided", status: 400
        return
      end

      # Save return SSO return url in cookie
      cookies[:sso_destination_url] = params[:return_url]
    end

    def check_current_user
      return_url = params[:return_url]

      if current_user
        # regenerate jwt cookie
        DebtCollective::SSO.new(current_user, cookies).set_jwt_cookie

        if request.xhr?
          cookies[:sso_destination_url] = return_url
        else
          redirect_to return_url
        end
      end
    end
  end

  module DebtCollectiveUsersController
    # Override this method to redirect to url if sso_destination_url cookie is present
    def perform_account_activation
      raise Discourse::InvalidAccess.new if honeypot_or_challenge_fails?(params)

      if @user = EmailToken.confirm(params[:token])
        # Log in the user unless they need to be approved
        if Guardian.new(@user).can_access_forum?
          @user.enqueue_welcome_message('welcome_user') if @user.send_welcome_message
          log_on_user(@user)

          # Redirect to SSO signup before Wizards
          if sso_destination_url = cookies[:sso_destination_url]
            cookies[:sso_destination_url] = nil
            return redirect_to(sso_destination_url)
          end

          if Wizard.user_requires_completion?(@user)
            return redirect_to(wizard_path)
          elsif destination_url = cookies[:destination_url]
            cookies[:destination_url] = nil
            return redirect_to(destination_url)
          elsif SiteSetting.enable_sso_provider && payload = cookies.delete(:sso_payload)
            return redirect_to(session_sso_provider_url + "?" + payload)
          end
        else
          @needs_approval = true
        end
      else
        flash.now[:error] = I18n.t('activation.already_done')
      end

      render layout: 'no_ember'
    end
  end

  if SiteSetting.enable_debtcollective_sso
    Discourse.current_user_provider = DebtCollective::CurrentUserProvider

    ::SessionController.class_eval do
      prepend DebtCollectiveSessionController

      before_action :check_return_url, only: [:sso_provider, :sso_provider_signup]
      before_action :check_current_user, only: [:sso_provider, :sso_provider_signup]
      skip_before_action :preload_json, :check_xhr, only: [:sso_provider_signup]
    end

    ::UsersController.class_eval do
      prepend DebtCollectiveUsersController
    end

    Discourse::Application.routes.append do
      get "session/sso_provider/signup" => "session#sso_provider_signup"
    end
  end
end
