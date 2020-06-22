# frozen_string_literal: true
require 'net/http'
require 'uri'

module Debtcollective
  class AlgoliaPlacesClient
    attr_reader :app_id, :api_key, :api_url

    def initialize(app_id: nil, api_key: nil)
      return nil unless app_id.present? && api_key.present?

      self.app_id = app_id
      self.api_key = api_key
      self.api_url = 'https://places-dsn.algolia.net/1/places/query'
    end

    # Returns HTTP::Response
    def query(query, options = { type: "address", "restrictSearchableAttributes": "postcode", hitsPerPage: 1 })
      payload = { query: query }.merge(options)

      Net::HTTP.post(
        URI(self.api_url),
        payload.to_json,
        self.headers
      )
    end

    private

    def headers
      {
        accept: "application/json",
        "Content-Type": "application/json",
        "X-Algolia-Application-Id": self.app_id,
        "X-Algolia-API-Key": self.api_key
      }
    end
  end
end
