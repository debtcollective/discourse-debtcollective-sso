# name: Debt Collective Discourse Utilities
# about: Miscellaneous utilities to make Debt Collective functionality work. Probably not useful to anyone else
# version: 0.0.1
# authors: Debt Syndicate Developers

after_initialize do
  class ::AdminUserIndexQuery
    def filter_by_ids
      if params[:ids].present?
        @query.where('"users"."id" in (:ids)', ids: params[:ids].split(",").map { |s| s.to_i })
      end
    end

    def find_users_query
      append filter_by_ids
      append filter_by_trust
      append filter_by_query_classification
      append filter_by_ip
      append filter_exclude
      append filter_by_search

      @query
    end
  end

  class ::Discourse::Cors
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
end
