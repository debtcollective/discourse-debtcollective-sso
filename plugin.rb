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

          if current_user.uploaded_avatar.present?
            base_url = Discourse.store.external? ? "#{Discourse.store.absolute_base_url}/" : Discourse.base_url
            avatar_url = "#{base_url}#{Discourse.store.get_path_for_upload(current_user.uploaded_avatar)}"
            sso.avatar_url = UrlHelper.absolute Discourse.store.cdn_url(avatar_url)
          else
            # return letter_avatar if no uploaded_avatar
            sso.avatar_url = current_user.small_avatar_url
          end

          if current_user.user_profile.profile_background_upload.present?
            sso.profile_background_url = UrlHelper.absolute(upload_cdn_path(
              current_user.user_profile.profile_background_upload.url
            ))
          end

          if current_user.user_profile.card_background_upload.present?
            sso.card_background_url = UrlHelper.absolute(upload_cdn_path(
              current_user.user_profile.card_background_upload.url
            ))
          end

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
      return_url = URI.parse(return_url.to_s)
      host = return_url.host

      if host.blank?
        return false, "return_url must be a valid URL"
      end

      if !host.end_with?(request.domain)
        return false, "return_url must be a valid subdomain"
      end

      true
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
