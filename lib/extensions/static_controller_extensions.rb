# frozen_string_literal: true
module DebtcollectiveSso
  module StaticControllerExtensions
    AUTH_PAGES = ['login', 'signup']
    PAGES_WITH_EMAIL_PARAM = ['login', 'password_reset', 'signup']
    MODAL_PAGES = ['password_reset', 'signup']

    def show
      return redirect_to(path '/') if current_user && (params[:id] == 'login' || params[:id] == 'signup')
      if SiteSetting.login_required? && current_user.nil? && ['faq', 'guidelines'].include?(params[:id])
        return redirect_to path('/login')
      end

      map = {
        "faq" => { redirect: "faq_url", topic_id: "guidelines_topic_id" },
        "tos" => { redirect: "tos_url", topic_id: "tos_topic_id" },
        "privacy" => { redirect: "privacy_policy_url", topic_id: "privacy_topic_id" }
      }

      @page = params[:id]

      if map.has_key?(@page)
        site_setting_key = map[@page][:redirect]
        url = SiteSetting.get(site_setting_key)
        return redirect_to(url) unless url.blank?
      end

      # The /guidelines route ALWAYS shows our FAQ, ignoring the faq_url site setting.
      @page = 'faq' if @page == 'guidelines'

      # Don't allow paths like ".." or "/" or anything hacky like that
      @page = @page.gsub(/[^a-z0-9\_\-]/, '')

      if map.has_key?(@page)
        @topic = Topic.find_by_id(SiteSetting.get(map[@page][:topic_id]))
        raise Discourse::NotFound unless @topic
        title_prefix = if I18n.exists?("js.#{@page}")
          I18n.t("js.#{@page}")
        else
          @topic.title
        end
        @title = "#{title_prefix} - #{SiteSetting.title}"
        @body = @topic.posts.first.cooked
        @faq_overriden = !SiteSetting.faq_url.blank?
        render :show, layout: !request.xhr?, formats: [:html]
        return
      end

      unless @title.present?
        @title = if SiteSetting.short_site_description.present?
          "#{SiteSetting.title} - #{SiteSetting.short_site_description}"
        else
          SiteSetting.title
        end
      end

      if I18n.exists?("static.#{@page}")
        render html: I18n.t("static.#{@page}"), layout: !request.xhr?, formats: [:html]
        return
      end

      if PAGES_WITH_EMAIL_PARAM.include?(@page) && params[:email]
        cookies[:email] = { value: params[:email], expires: 1.day.from_now }
      end

      if AUTH_PAGES.include?(@page)
        render html: nil, layout: true
        return
      end

      file = "static/#{@page}.#{I18n.locale}"
      file = "static/#{@page}.en" if lookup_context.find_all("#{file}.html").empty?
      file = "static/#{@page}"    if lookup_context.find_all("#{file}.html").empty?

      if lookup_context.find_all("#{file}.html").any?
        render file, layout: !request.xhr?, formats: [:html]
        return
      end

      if MODAL_PAGES.include?(@page)
        render html: nil, layout: true
        return
      end

      raise Discourse::NotFound
    end
  end

  ::StaticController.class_eval do
    prepend DebtcollectiveSso::StaticControllerExtensions
    prepend_view_path(Rails.root.join('plugins', DebtcollectiveSso::PLUGIN_NAME, 'app', 'views'))
  end
end
