# frozen_string_literal: true
module Debtcollective
  class UserProfileService
    include BaseService

    def self.extend_user_profile(user)
      # get_address_info(user.zip)
      # update user fields with address info (city, state and other useful info)
      # add_user_to_state group
    end

    def self.get_address_info(zip: null)
      # from zip code get
      # - state
      # - city
      { state: 'valid state', city: 'valid city' }
    end

    def self.add_user_to_group(user)
      state = user.custom_fields['user_field_1']

      return if state.nil?

      group_name = state.split.map(&:camelize).join
      group = Group.find_by_name(group_name)

      if group.nil?
        capture_message("A state group wasn't found", extra: { user_id: user.id, state: state, group_name: group_name })
        return
      end

      group.add(user)
      group.save
    end
  end
end
