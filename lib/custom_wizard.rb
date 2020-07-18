module Debtcollective
  class CustomWizard
    class << self
      def collectives
        @collectives ||= [
          "court_fines_and_fees",
          "student_debt",
          "housing_debt",
          "auto_loans",
          "payday_loans",
          "medical_debt",
          "for_profit_colleges",
          "credit_card_debt",
          "solidarity_bloc"
        ]
      end

      def add_user_to_groups(user, groups)
        groups.each do |group_name, is_member|
          group = Group.find_by(name: group_name)

          if is_member
            group.add(user)
          else
            group.remove(user)
          end

          group.save
        end
      end

      def solidarity_pm_content(user)
        "Hello @#{user.username}!\n\nThank you for offering to help in solidarity with people in debt. Tell us a little about yourself and what skills you have to share so we can get started."
      end

      def send_solidarity_pm(user)
        bloc_manager = User.find_by_username(SiteSetting.debtcollective_solidarity_message_author)
        bloc_manager ||= Discourse.system_user

        PostCreator.create(bloc_manager,
          archetype: Archetype.private_message,
          title: SiteSetting.debtcollective_solidarity_message_title,
          raw: solidarity_pm_content(user),
          target_usernames: [user.username],
          target_group_names: []
        )
      end
    end
  end
end
