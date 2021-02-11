# frozen_string_literal: true
# https://github.com/discourse/discourse/blob/master/app/controllers/invites_controller.rb
module Debtcollective
  module InvitesController
    def perform_accept_invitation
      params.require(:id)
      params.permit(:email, :username, :name, :password, :timezone, user_custom_fields: {})
      invite = Invite.find_by(invite_key: params[:id])

      if invite.present?
        begin
          user = if invite.is_invite_link?
            invite.redeem_invite_link(email: params[:email], username: params[:username], name: params[:name], password: params[:password], user_custom_fields: params[:user_custom_fields], ip_address: request.remote_ip)
          else
            invite.redeem(username: params[:username], name: params[:name], password: params[:password], user_custom_fields: params[:user_custom_fields], ip_address: request.remote_ip)
          end

          if user.present?
            log_on_user(user) if user.active?
            user.update_timezone_if_missing(params[:timezone])
            post_process_invite(user)
            response = { success: true }
          else
            response = { success: false, message: I18n.t('invite.not_found_json') }
          end

          if user.present? && user.active?
            topic = invite.topics.first
            response[:redirect_to] = path("/")
            response[:redirect_to] = topic.present? ? path("#{topic.relative_url}") : path("/")

            # If this is a new user or first login, redirect
            # we only set it if topic invite is nil
            redirect_to = SiteSetting.debtcollective_redirect_url_after_signup
            if (user.new_user? || !user.seen_before?) && redirect_to.present? && topic.blank?
              response[:redirect_to] = redirect_to
            end
          elsif user.present?
            response[:message] = I18n.t('invite.confirm_email')
          end

          render json: response
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
          render json: {
            success: false,
            errors: e.record&.errors&.to_hash || {},
            message: I18n.t('invite.error_message')
          }
        rescue Invite::UserExists => e
          render json: { success: false, message: [e.message] }
        end
      else
        render json: { success: false, message: I18n.t('invite.not_found_json') }
      end
    end
  end

  ::InvitesController.class_eval do
    prepend Debtcollective::InvitesController
  end
end
