# frozen_string_literal: true
# https://github.com/discourse/discourse/blob/master/app/controllers/users_controller.rb
module Debtcollective
  module UsersController
    # Add redirection to sso_destination_url if avaiable
    def account_created
      if current_user.present?
        if SiteSetting.enable_sso_provider && payload = cookies.delete(:sso_payload)
          return redirect_to(session_sso_provider_url + "?" + payload)
        elsif sso_destination_url = cookies.delete(:sso_destination_url)
          return redirect_to(sso_destination_url)
        elsif destination_url = cookies.delete(:destination_url)
          return redirect_to(destination_url)
        else
          return redirect_to(path('/'))
        end
      end

      @custom_body_class = "static-account-created"
      @message = session['user_created_message'] || I18n.t('activation.missing_session')
      @account_created = { message: @message, show_controls: false }

      if session_user_id = session[::SessionController::ACTIVATE_USER_KEY]
        if user = User.where(id: session_user_id.to_i).first
          @account_created[:username] = user.username
          @account_created[:email] = user.email
          @account_created[:show_controls] = !user.from_staged?
        end
      end

      store_preloaded("accountCreated", MultiJson.dump(@account_created))
      expires_now

      respond_to do |format|
        format.html { render "default/empty" }
        format.json { render json: success_json }
      end
    end

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

    def create
      params.require(:email)
      params.require(:invite_code) if SiteSetting.require_invite_code
      params.permit(:user_fields)

      unless SiteSetting.allow_new_registrations
        return fail_with("login.new_registrations_disabled")
      end

      if params[:password] && params[:password].length > User.max_password_length
        return fail_with("login.password_too_long")
      end

      if params[:email].length > 254 + 1 + 253
        return fail_with("login.email_too_long")
      end

      if SiteSetting.require_invite_code && SiteSetting.invite_code.strip.downcase != params[:invite_code].strip.downcase
        return fail_with("login.wrong_invite_code")
      end

      # We use this to create accounts from the Membership app
      if is_api? && guardian.is_admin? && params[:username].blank?
        params[:username] = UserNameSuggester.suggest(user_params[:email])
      end

      # defered username check
      params.require(:username)

      if clashing_with_existing_route?(params[:username]) || User.reserved_username?(params[:username])
        return fail_with("login.reserved_username")
      end

      params[:locale] ||= I18n.locale unless current_user

      new_user_params = user_params.except(:timezone)

      user = User.where(staged: true).with_email(new_user_params[:email].strip.downcase).first

      if user
        user.active = false
        user.unstage!
      end

      user ||= User.new
      user.attributes = new_user_params

      # Handle API approval and
      # auto approve users based on auto_approve_email_domains setting
      if user.approved? || EmailValidator.can_auto_approve_user?(user.email)
        ReviewableUser.set_approved_fields!(user, current_user)
      end

      # Handle custom fields
      user_fields = UserField.all
      if user_fields.present?
        field_params = params[:user_fields] || {}
        fields = user.custom_fields

        user_fields.each do |f|
          field_val = field_params[f.id.to_s]
          if field_val.blank?
            return fail_with("login.missing_user_field") if f.required?
          else
            fields["#{User::USER_FIELD_PREFIX}#{f.id}"] = field_val[0...UserField.max_length]
          end
        end

        user.custom_fields = fields
      end

      authentication = UserAuthenticator.new(user, session)

      if !authentication.has_authenticator? && !SiteSetting.enable_local_logins && !(current_user&.admin? && is_api?)
        return render body: nil, status: :forbidden
      end

      authentication.start

      if authentication.email_valid? && !authentication.authenticated?
        # posted email is different that the already validated one?
        return fail_with('login.incorrect_username_email_or_password')
      end

      activation = UserActivator.new(user, request, session, cookies)
      activation.start

      # just assign a password if we have an authenticator and no password
      # this is the case for Twitter
      user.password = SecureRandom.hex if user.password.blank? && authentication.has_authenticator?

      if user.save
        authentication.finish
        activation.finish
        user.update_timezone_if_missing(params[:timezone])

        secure_session[::ApplicationController::HONEYPOT_KEY] = nil
        secure_session[::ApplicationController::CHALLENGE_KEY] = nil

        # save user email in session, to show on account-created page
        session["user_created_message"] = activation.message
        session[::SessionController::ACTIVATE_USER_KEY] = user.id

        # If the user was created as active this will
        # ensure their email is confirmed and
        # add them to the review queue if they need to be approved
        user.activate if user.active?

        response = {
          success: true,
          active: user.active?,
          message: activation.message,
          user_id: user.id
        }

        if is_api?
          # Create a signin link to be used to login the user for the first time.
          email_token = user.email_tokens.create!(email: user.email)

          response[:email_token] = email_token.token
          response[:username] = user.username
        end

        render json: response
      elsif SiteSetting.hide_email_address_taken && user.errors[:primary_email]&.include?(I18n.t('errors.messages.taken'))
        session["user_created_message"] = activation.success_message

        if existing_user = User.find_by_email(user.primary_email&.email)
          Jobs.enqueue(:critical_user_email, type: :account_exists, user_id: existing_user.id)
        end

        render json: {
          success: true,
          active: user.active?,
          message: activation.success_message,
          user_id: user.id
        }
      else
        errors = user.errors.to_hash
        errors[:email] = errors.delete(:primary_email) if errors[:primary_email]

        render json: {
          success: false,
          message: I18n.t(
            'login.errors',
            errors: user.errors.full_messages.join("\n")
          ),
          errors: errors,
          values: {
            name: user.name,
            username: user.username,
            email: user.primary_email&.email
          },
          is_developer: UsernameCheckerService.is_developer?(user.email)
        }
      end
    rescue ActiveRecord::StatementInvalid
      render json: {
        success: false,
        message: I18n.t("login.something_already_taken")
      }
    end
  end

  ::UsersController.class_eval do
    prepend Debtcollective::UsersController
  end
end
