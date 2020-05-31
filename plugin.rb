# frozen_string_literal: true

# name: discourse-debtcollective-sso
# about: Extensions to Discourse SSO provider to work the way we need
# version: 0.0.3
# authors: @debtcollective

require 'jwt'

after_initialize do
  load File.expand_path('../lib/sso.rb', __FILE__)
  load File.expand_path('../lib/current_user_provider.rb', __FILE__)

  module DebtCollectiveSessionController
    def sso_cookies
      redirect_to path('/login')
    end

    def sso_cookies_signup
      redirect_to path('/signup')
    end

    # leave this here until we launch the new tools app
    # to make it backwards compatible with the current tools
    def sso_provider(payload = nil)
      payload ||= request.query_string

      if SiteSetting.enable_sso_provider
        begin
          sso = SingleSignOnProvider.parse(payload)
        rescue SingleSignOnProvider::BlankSecret
          render plain: I18n.t("sso.missing_secret"), status: 400
          return
        end

        if sso.return_sso_url.blank?
          render plain: "return_sso_url is blank, it must be provided", status: 400
          return
        end

        if current_user
          sso.name = current_user.name
          sso.username = current_user.username
          sso.email = current_user.email
          sso.external_id = current_user.id.to_s
          sso.admin = current_user.admin?
          sso.moderator = current_user.moderator?
          sso.groups = current_user.groups.pluck(:name).join(",")

          # this method return either a letter avatar or the cdn upload
          sso.avatar_url = current_user.avatar_template_url.gsub('{size}', '100')

          # return user fields
          sso.custom_fields["user_state"] = current_user.custom_fields.fetch("user_field_1", "").to_s
          sso.custom_fields["user_zip"] = current_user.custom_fields.fetch("user_field_2", "").to_s
          sso.custom_fields["user_phone_number"] = current_user.custom_fields.fetch("user_field_3", "").to_s

          if request.xhr?
            cookies[:sso_destination_url] = sso.to_url(sso.return_sso_url)
          else
            redirect_to sso.to_url(sso.return_sso_url)
          end
        else
          cookies[:sso_payload] = request.query_string
          redirect_to path('/login')
        end
      else
        render body: nil, status: 404
      end
    end

    private

    def check_return_url
      valid, message = is_valid_return_url?(params[:return_url])

      render plain: message, status: 400 unless valid
    end

    def check_current_user
      if current_user
        # regenerate jwt cookie
        DebtCollective::SSO.new(current_user, cookies).set_jwt_cookie

        # redirect to return_url
        return_url = params[:return_url]
        redirect_to(return_url)
      else
        # Save return SSO return url in cookie
        cookies[:sso_destination_url] = params[:return_url]
      end
    end

    def is_valid_return_url?(return_url)
      invalid_message = 'invalid return_url'

      # parse URL while catching InvalidURI errors
      begin
        return_url = URI.parse(return_url.to_s)
      rescue URI::InvalidURIError
        return false, invalid_message
      end

      host = return_url.host

      if host.blank?
        return false, invalid_message
      end

      if !host.end_with?(request.domain)
        return false, invalid_message
      end

      true
    end
  end

  module DebtCollectiveUsersController
    # Override to redirect to url if sso_destination_url cookie is present
    def create
      params.require(:email)
      params.require(:username)
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

        secure_session[HONEYPOT_KEY] = nil
        secure_session[CHALLENGE_KEY] = nil

        # save user email in session, to show on account-created page
        session["user_created_message"] = activation.message
        session[SessionController::ACTIVATE_USER_KEY] = user.id

        # If the user was created as active this will
        # ensure their email is confirmed and
        # add them to the review queue if they need to be approved
        if user.active?
          user.activate

          # This is where we redirect users using the SSO destination URL
          # We are working around Discourse code, that's why we need to
          # repeat this code in multiple places inside this method.
          # Redirect to SSO signup
          if sso_destination_url = cookies[:sso_destination_url]
            cookies.delete(:sso_destination_url)

            return redirect_to(sso_destination_url)
          end
        end

        render json: {
          success: true,
          active: user.active?,
          message: activation.message,
          user_id: user.id
        }
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

    if SiteSetting.enable_debtcollective_sso
      Discourse.current_user_provider = DebtCollective::CurrentUserProvider

      ::SessionController.class_eval do
        prepend DebtCollectiveSessionController

        before_action :check_return_url, only: [:sso_cookies, :sso_cookies_signup]
        before_action :check_current_user, only: [:sso_cookies, :sso_cookies_signup]
        skip_before_action :preload_json, :check_xhr, only: [:sso_cookies, :sso_cookies_signup]
      end

      ::UsersController.class_eval do
        prepend DebtCollectiveUsersController
      end

      Discourse::Application.routes.append do
        get "session/sso_cookies/signup" => "session#sso_cookies_signup"
        get "session/sso_cookies" => "session#sso_cookies"
      end
    end
  end
end
