# frozen_string_literal: true
require 'net/http'
require 'uri'

module Debtcollective
  class AlgoliaPlacesClient
    # Returns JSON response or nil
    def self.query(query, options = { type: "address", "restrictSearchableAttributes": "postcode", hitsPerPage: 1 })
      payload = { query: query }.merge(options)
      api_url = 'https://places-dsn.algolia.net/1/places/query'

      response = Net::HTTP.post(
        URI(api_url),
        payload.to_json,
        self.headers
      )

      case response
      when Net::HTTPSuccess then
        success_response(response)
      else
        Raven.capture_message("Error while making Algolia Places request", extra: { status: response.status, body: response.body }) if defined?(Raven)

        nil
      end
    end

    private

    def self.success_response(response)
      body = response.body
      json = JSON.parse(body)

      # We return the first result
      result = json['hits'].first

      {
        city: result['city']['default'].first,
        country: result['country']['default'],
        country_code: result['country_code'],
        county: result['county']['default'].first,
        objectID: result['objectID'],
        geoloc: result['_geoloc'],
        postcodes: result['postcode'],
        state: result['administrative'].first
      }.with_indifferent_access
    end

    def self.headers
      {
        accept: "application/json",
        "Content-Type": "application/json",
        "X-Algolia-Application-Id": SiteSetting.debtcollective_algolia_app_id,
        "X-Algolia-API-Key": SiteSetting.debtcollective_algolia_api_key
      }
    end
  end
end
