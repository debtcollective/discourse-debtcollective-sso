# frozen_string_literal: true
require 'jwt'

module Debtcollective
  class SSO
    include GlobalPath

    def initialize(user, cookies = {})
      @user = user
      @cookies = cookies
    end

    def generate_jwt
      hmac_secret = SiteSetting.sso_jwt_secret
      jwt_alg = "HS256"

      token = JWT.encode(jwt_payload, hmac_secret, jwt_alg)
    end

    def set_jwt_cookie
      cookie_domain = SiteSetting.sso_cookie_domain
      cookie_name = SiteSetting.sso_cookie_name
      secure = Rails.env.production?

      @cookies[cookie_name] = {
        domain: cookie_domain,
        expires: SiteSetting.maximum_session_age.hours.from_now,
        httponly: true,
        secure: SiteSetting.force_https,
        value: generate_jwt,
      }
    end

    def remove_jwt_cookie
      cookie_domain = SiteSetting.sso_cookie_domain
      cookie_name = SiteSetting.sso_cookie_name

      @cookies.delete(cookie_name, domain: cookie_domain)
    end

    private

    def user_avatar_url
      @user.avatar_template_url.gsub('{size}', '100')
    end

    def user_profile_background_url
      if @user.user_profile.profile_background_upload.present?
        profile_background_url = UrlHelper.absolute(upload_cdn_path(
          @user.user_profile.profile_background_upload.url
        ))
      end
    end

    def user_card_background_url
      if @user.user_profile.card_background_upload.present?
        card_background_url = UrlHelper.absolute(upload_cdn_path(
          @user.user_profile.card_background_upload.url
        ))
      end
    end

    def user_custom_fields
      custom_fields = {
        state: @user.custom_fields.fetch("user_field_1", "").to_s,
        zip_code: @user.custom_fields.fetch("user_field_2", "").to_s,
        phone_number: @user.custom_fields.fetch("user_field_3", "").to_s
      }
    end

    def jwt_payload
      groups = @user.groups.collect(&:name)

      payload = {
        active: @user.active,
        admin: @user.admin?,
        avatar_url: user_avatar_url,
        created_at: @user.created_at,
        custom_fields: user_custom_fields,
        email: @user.email,
        external_id: @user.id,
        groups: groups,
        last_seen_at: @user.last_seen_at,
        moderator: @user.moderator?,
        name: @user.name,
        updated_at: @user.updated_at,
        username: @user.username,
      }
    end
  end
end
