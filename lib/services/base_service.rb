# frozen_string_literal: true
module Debtcollective
  module BaseService
    def self.capture_message(message, attrs = {})
      Raven.capture_message(message, attrs) if defined?(Raven)
    end
  end
end
