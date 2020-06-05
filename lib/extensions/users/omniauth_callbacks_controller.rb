# https://github.com/discourse/discourse/blob/master/app/controllers/users/omniauth_callbacks_controller.rb
module Debtcollective
  module Users
    module OmniauthCallbacksController
      def complete
        auth = request.env["omniauth.auth"]
        raise Discourse::NotFound unless request.env["omniauth.auth"]

        auth[:session] = session

        authenticator = self.class.find_authenticator(params[:provider])
        provider = DiscoursePluginRegistry.auth_providers.find { |p| p.name == params[:provider] }

        if session.delete(:auth_reconnect) && authenticator.can_connect_existing_user? && current_user
          # Save to redis, with a secret token, then redirect to confirmation screen
          token = SecureRandom.hex
          Discourse.redis.setex "#{Users::AssociateAccountsController::REDIS_PREFIX}_#{current_user.id}_#{token}", 10.minutes, auth.to_json
          return redirect_to Discourse.base_uri("/associate/#{token}")
        else
          @auth_result = authenticator.after_authenticate(auth)
          DiscourseEvent.trigger(:after_auth, authenticator, @auth_result)
        end

        preferred_origin = request.env['omniauth.origin']

        if SiteSetting.enable_sso_provider && payload = cookies.delete(:sso_payload)
          preferred_origin = session_sso_provider_url + "?" + payload
        elsif cookies[:destination_url].present?
          preferred_origin = cookies[:destination_url]
          cookies.delete(:destination_url)
        end

        if preferred_origin.present?
          parsed = begin
            URI.parse(preferred_origin)
          rescue URI::Error
          end

          if parsed && # Valid
             (parsed.host == nil || parsed.host == Discourse.current_hostname) && # Local
             !parsed.path.starts_with?(Discourse.base_uri("/auth/")) # Not /auth URL
            @origin = +"#{parsed.path}"
            @origin << "?#{parsed.query}" if parsed.query
          end
        end

        if @origin.blank?
          @origin = Discourse.base_uri("/")
        end

        @auth_result.destination_url = @origin

        if @auth_result.failed?
          flash[:error] = @auth_result.failed_reason.html_safe
          render('failure')
        else
          @auth_result.authenticator_name = authenticator.name
          complete_response_data
          cookies['_bypass_cache'] = true
          cookies[:authentication_data] = {
            value: @auth_result.to_client_hash.to_json,
            path: Discourse.base_uri("/")
          }

          # DC modification
          # Here we check if there's an authenticated user and a sso_redirect_url
          # If both are present then we redirect the user back
          if @auth_result.authenticated && current_user && cookies[:sso_destination_url]
            redirect_url = cookies.delete(:sso_destination_url)
            return redirect_to redirect_url
          end

          redirect_to @origin
        end
      end
    end
  end

  ::Users::OmniauthCallbacksController.class_eval do
    prepend Debtcollective::Users::OmniauthCallbacksController
  end
end
