# frozen_string_literal: true

require 'rails_helper'

describe "UsersController" do
  describe 'Create user via api' do
    context "with an admin account" do
      it 'returns user data including auto generated username' do
        post_user_params ={
          name: "orlando test",
          username: nil,
          password: "strongpassword",
          email: "orlando@test.com"
        }
        generated_username = UserNameSuggester.suggest(post_user_params[:email])
        api_key = Fabricate(:api_key, user: Fabricate(:admin))

        post "/u.json", params: post_user_params, headers: { HTTP_API_KEY: api_key.key }
        json = response.parsed_body

        expect(response.status).to eq(200)
        expect(json['success']).to eq(true)
        expect(json['message']).to be_present
        expect(json['username']).to eq(generated_username)
      end
    end
  end
end
