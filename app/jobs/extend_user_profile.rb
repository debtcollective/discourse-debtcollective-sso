# frozen_string_literal: true
module Jobs
  class ExtendUserProfile < ::Jobs::Base
    def execute(args)
      user = User.find(args[:user_id])

      Debtcollective::UserProfileService.execute(user)
    end
  end
end
