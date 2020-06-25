# frozen_string_literal: true
module Debtcollective
  class UserProfileService
    include BaseService

    def self.execute(user)
      add_user_location_data(user)
      add_user_to_state_group(user)
    end

    def self.add_user_location_data(user)
      # Zip code is set on signup
      zip_code = user_field_value_by_name(user, 'Zip Code')
      location = AlgoliaPlacesClient.query(zip_code)

      return if location.nil?

      # update user fields with address info (city and state)
      set_user_field_value_by_name(user, 'State', location["state"])
      set_user_field_value_by_name(user, 'City', location["city"])

      # we will store the rest of the info we have as custom fields
      location['zip_code'] = zip_code
      # this data will be stored as JSON, we need parse it to have a ruby hash
      user.custom_fields['tdc_user_location'] = location
      user.save
    end

    def self.add_user_to_state_group(user)
      state = user_field_value_by_name(user, 'State')

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

    private

    def self.user_field_value_by_name(user, field_name)
      field = UserField.find_by(name: field_name)

      user.user_fields.fetch(field.id.to_s, "") if field
    end

    def self.set_user_field_value_by_name(user, field_name, value)
      field = UserField.find_by(name: field_name)

      user.custom_fields["user_field_#{field.id}"] = value if field
    end
  end
end
