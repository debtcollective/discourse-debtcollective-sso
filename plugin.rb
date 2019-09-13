# frozen_string_literal: true

# name: discourse-debtcollective-sso
# about: Extensions to Discourse SSO provider to work the way we need
# version: 0.0.2
# authors: @debtcollective

require 'jwt'

after_initialize do
  class DebtCollectiveSSO
    COOKIE_DOMAIN = ENV["JWT_COOKIE_DOMAIN"] || ".lvh.me"
    COOKIE_NAME = 'tdc_auth_token'
    JWT_SECRET = ENV['JWT_SECRET'] || 'testing123'

    def initialize(user, cookies = {})
      @user = user
      @cookies = cookies
    end

    def generate_jwt
      hmac_secret = JWT_SECRET
      jwt_alg = "HS256"

      token = JWT.encode(jwt_payload, hmac_secret, jwt_alg)
    end

    def set_jwt_cookie
      domain = ENV["JWT_COOKIE_DOMAIN"] || ".lvh.me"
      secure = Rails.env.production?

      @cookies[COOKIE_NAME] = {
        domain: COOKIE_DOMAIN,
        expires: SiteSetting.maximum_session_age.hours.from_now,
        httponly: true,
        secure: SiteSetting.force_https,
        value: generate_jwt,
      }
    end

    def remove_jwt_cookie
      @cookies.delete(COOKIE_NAME, domain: COOKIE_DOMAIN)
    end

    private

    def user_avatar_url
      avatar_url = @user.small_avatar_url

      if @user.uploaded_avatar.present?
        base_url = Discourse.store.external? ? "#{Discourse.store.absolute_base_url}/" : Discourse.base_url
        avatar_url = "#{base_url}#{Discourse.store.get_path_for_upload(@user.uploaded_avatar)}"
      end

      avatar_url
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
        zip_code: @user.custom_fields.fetch("user_field_1", "").to_s,
        state: @user.custom_fields.fetch("user_field_2", "").to_s,
        phone_number: @user.custom_fields.fetch("user_field_3", "").to_s
      }
    end

    def jwt_payload
      groups = @user.groups.collect(&:name)

      payload = {
        active: @user.active,
        admin: @user.admin?,
        avatar_url: user_avatar_url,
        card_background_url: user_card_background_url,
        created_at: @user.created_at,
        custom_fields: user_custom_fields,
        email: @user.email,
        external_id: @user.id,
        groups: groups,
        last_seen_at: @user.last_seen_at,
        moderator: @user.moderator?,
        name: @user.name,
        profile_background_url: user_profile_background_url,
        updated_at: @user.updated_at,
        username: @user.username,
      }
    end
  end

  class DebtCollectiveCurrentUserProvider < ::Auth::DefaultCurrentUserProvider
    def log_on_user(user, session, cookies, opts = {})
      super(user, session, cookies, opts)

      DebtCollectiveSSO.new(user, cookies).set_jwt_cookie
    end

    def log_off_user(session, cookies)
      super(session, cookies)

      DebtCollectiveSSO.new(current_user, cookies).remove_jwt_cookie
    end

    def refresh_session(user, session, cookies)
      # if user was not loaded, no point refreshing session
      # it could be an anonymous path, this would add cost
      return if is_api? || !@env.key?(CURRENT_USER_KEY)

      if !is_user_api? && @user_token && @user_token.user == user
        rotated_at = @user_token.rotated_at

        needs_rotation = @user_token.auth_token_seen ? rotated_at < UserAuthToken::ROTATE_TIME.ago : rotated_at < UserAuthToken::URGENT_ROTATE_TIME.ago

        if needs_rotation
          if @user_token.rotate!(user_agent: @env['HTTP_USER_AGENT'],
                                 client_ip: @request.ip,
                                 path: @env['REQUEST_PATH'])
            cookies[TOKEN_COOKIE] = cookie_hash(@user_token.unhashed_auth_token)

            # extend to set jwt cookie when refreshing session
            DebtCollectiveSSO.new(user, cookies).set_jwt_cookie
          end
        end
      end

      if !user && cookies.key?(TOKEN_COOKIE)
        cookies.delete(TOKEN_COOKIE)

        # extend to remove jwt cookie
        DebtCollectiveSSO.new(current_user, cookies).remove_jwt_cookie
      end
    end
  end

  if SiteSetting.enable_debtcollective_sso
    Discourse.current_user_provider = DebtCollectiveCurrentUserProvider
  end
end
