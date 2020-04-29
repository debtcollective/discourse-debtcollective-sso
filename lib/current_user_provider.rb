# frozen_string_literal: true

module DebtcollectiveSso
  class CurrentUserProvider < ::Auth::DefaultCurrentUserProvider
    def log_on_user(user, session, cookies, opts = {})
      super(user, session, cookies, opts)

      SSO.new(user, cookies).set_jwt_cookie
    end

    def log_off_user(session, cookies)
      super(session, cookies)

      SSO.new(current_user, cookies).remove_jwt_cookie
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
            SSO.new(user, cookies).set_jwt_cookie
          end
        end
      end

      if !user && cookies.key?(TOKEN_COOKIE)
        cookies.delete(TOKEN_COOKIE)

        # extend to remove jwt cookie
        SSO.new(current_user, cookies).remove_jwt_cookie
      end
    end
  end
end
