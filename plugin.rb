# name: discourse-debtcollective-sso
# about: Extensions to Discourse SSO provider to work the way we need
# version: 0.0.2
# authors: @debtcollective

after_initialize do
  # This is needed by the dc-vue-header in order to work
  class Discourse::Cors
    def self.apply_headers(cors_origins, env, headers)
      origin = nil

      if cors_origins
        if origin = env['HTTP_ORIGIN']
          origin = nil unless cors_origins.include?(origin)
        end

        headers['Access-Control-Allow-Origin'] = origin || cors_origins[0]
        headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-CSRF-Token, Discourse-Visible'
        headers['Access-Control-Expose-Headers'] = 'X-Discourse-Username'
        headers['Access-Control-Allow-Credentials'] = 'true'
        headers['Access-Control-Allow-Methods'] = 'HEAD, OPTIONS, GET, DELETE'
      end

      headers
    end
  end

  # SSO payload to return whitelisted user custom_fields
  module DebtCollectiveSessionController
    def sso_provider(payload = nil)
      payload ||= request.query_string

      if SiteSetting.enable_sso_provider
        sso = SingleSignOnProvider.parse(payload)

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

          # return letter_avatar if no uploaded_avatar
          if current_user.uploaded_avatar.present?
            base_url = Discourse.store.external? ? "#{Discourse.store.absolute_base_url}/" : Discourse.base_url
            avatar_url = "#{base_url}#{Discourse.store.get_path_for_upload(current_user.uploaded_avatar)}"
            sso.avatar_url = UrlHelper.absolute Discourse.store.cdn_url(avatar_url)
          else
            sso.avatar_url = current_user.small_avatar_url
          end

          if current_user.user_profile.profile_background.present?
            sso.profile_background_url = UrlHelper.absolute upload_cdn_path(current_user.user_profile.profile_background)
          end

          if current_user.user_profile.card_background.present?
            sso.card_background_url = UrlHelper.absolute upload_cdn_path(current_user.user_profile.card_background)
          end

          # return user fields
          sso.custom_fields["user_state"] = current_user.custom_fields.fetch("user_field_1").to_s
          sso.custom_fields["user_zip"] = current_user.custom_fields.fetch("user_field_2").to_s
          sso.custom_fields["user_phone_number"] = current_user.custom_fields.fetch("user_field_3").to_s

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
  end

  ::SessionController.class_eval do
    prepend DebtCollectiveSessionController
  end
end
