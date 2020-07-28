require 'rails_helper'

describe "CollectivesController" do
  describe 'PUT join' do
    it 'adds current_user to category group' do
      user = Fabricate(:user)
      group = Fabricate(:group, name: 'collective_group')
      category = Fabricate(:category, name: 'Collective', custom_fields: { "tdc_is_collective": true })
      category.permissions = { group.id => :full }
      category.save()
      sign_in(user)

      put "/collectives/#{category.id}/join.json"

      user.reload

      expect(response.status).to eq(200)
      expect(user.groups).to include(group)
    end

    context 'with invalid collective id' do
      it 'returns 404' do
        user = Fabricate(:user)
        sign_in(user)

        put "/collectives/123/join.json"

        expect(response.status).to eq(404)
      end
    end

    context 'with a category that is not a collective' do
      it 'returns 400' do
        user = Fabricate(:user)
        category = Fabricate(:category, name: 'Category')
        sign_in(user)

        put "/collectives/#{category.id}/join.json"

        expect(response.status).to eq(400)
      end
    end
  end
end
