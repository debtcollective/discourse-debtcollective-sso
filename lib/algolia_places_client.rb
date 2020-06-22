# frozen_string_literal: true
module Debtcollective
  class AlgoliaPlacesClient
    attr_reader :client

    def initialize(app_id: nil, api_key: nil)
      return nil unless app_id.present? && api_key.present?
    end
  end
end
