# frozen_string_literal: true
module Debtcollective
  module BaseService
    def self.capture_message(message, attrs = {})
      if Module.const_defined?('Raven')
        Raven.capture_message(message, attrs)
      end
    end
  end
end
