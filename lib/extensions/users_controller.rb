# frozen_string_literal: true
module Debtcollective
  module UsersController
    # Override to redirect to url if sso_destination_url cookie is present
    def perform_account_activation
      raise Discourse::InvalidAccess.new if honeypot_or_challenge_fails?(params)

      if @user = EmailToken.confirm(params[:token])
        # Log in the user unless they need to be approved
        if Guardian.new(@user).can_access_forum?
          @user.enqueue_welcome_message('welcome_user') if @user.send_welcome_message
          log_on_user(@user)

          # CustomWizard plugin has side effect when calling Wizard.user_requires_completion?(@user)
          # We still need this side effect so the wizard is rendered when the user goes to Discourse for the first time
          custom_wizard_redirect = Wizard.user_requires_completion?(@user)

          # Redirect to SSO signup before Wizards
          if sso_destination_url = cookies[:sso_destination_url]
            cookies.delete(:sso_destination_url)

            return redirect_to(sso_destination_url)
          end

          if custom_wizard_redirect
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

  ::UsersController.class_eval do
    prepend Debtcollective::UsersController
  end
end
