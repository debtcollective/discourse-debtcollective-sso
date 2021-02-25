# frozen_string_literal: true

require 'rails_helper'

describe "UsersController" do
  describe '#create' do
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

    context "with a user account" do
      it 'returns an error' do
        post_user_params ={
          name: "orlando test",
          username: nil,
          password: "strongpassword",
          email: "orlando@test.com"
        }
        generated_username = UserNameSuggester.suggest(post_user_params[:email])
        api_key = Fabricate(:api_key, user: Fabricate(:user))

        post "/u.json", params: post_user_params, headers: { HTTP_API_KEY: api_key.key }
        json = response.parsed_body

        expect(response.status).to eq(400)
        expect(json['errors']).to be_present
        expect(json['success']).to eq(nil)
      end
    end
  end

  describe '#email_token' do
    context "with an admin account" do
      it 'returns email_token if user was found' do
        user = Fabricate(:user)
        api_key = Fabricate(:api_key, user: Fabricate(:admin))
        params = {
          login: user.email
        }

        post "/u/email-token", params: params, headers: { HTTP_API_KEY: api_key.key }
        json = response.parsed_body

        user.reload

        expect(response.status).to eq(200)
        expect(json['success']).to eq("OK")
        expect(json['user_found']).to eq(true)
        expect(json['email_token']).to eq(user.email_tokens.last.token)
      end

      it 'returns user_found false if no user is found' do
        user = Fabricate(:user)
        api_key = Fabricate(:api_key, user: Fabricate(:admin))
        params = {
          login: "test@example.com"
        }

        post "/u/email-token", params: params, headers: { HTTP_API_KEY: api_key.key }
        json = response.parsed_body

        expect(response.status).to eq(200)
        expect(json['success']).to eq("OK")
        expect(json['user_found']).to eq(false)
        expect(json['email_token']).not_to be_present
      end
    end

    context "with a user account" do
      it 'returns not found' do
        user = Fabricate(:user)
        api_key = Fabricate(:api_key, user: Fabricate(:user))
        params = {
          login: user.email
        }

        post "/u/email-token", params: params, headers: { HTTP_API_KEY: api_key.key }

        expect(response.status).to eq(404)
      end
    end
  end
end
