# frozen_string_literal: true
module Debtcollective
  module SessionController
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
        Debtcollective::SSO.new(current_user, cookies).set_jwt_cookie

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

  ::SessionController.class_eval do
    prepend Debtcollective::SessionController

    before_action :check_return_url, only: [:sso_cookies, :sso_cookies_signup]
    before_action :check_current_user, only: [:sso_cookies, :sso_cookies_signup]
    skip_before_action :preload_json, :check_xhr, only: [:sso_cookies, :sso_cookies_signup]
  end
end
