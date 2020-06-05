# frozen_string_literal: true

require 'rails_helper'

describe Debtcollective::SSO do
  class FakeCookieStore < Hash
    def delete(key, opts = {})
      self[key] = nil
    end
  end

  let(:user) { Fabricate(:user) }

  before(:all) do
    SiteSetting.sso_cookie_domain = 'example.com'
    SiteSetting.sso_cookie_name = 'tdc_auth_cookie'
    SiteSetting.sso_jwt_secret = 'elsecreto'
  end

  it '#generate_jwt' do
    cookies = FakeCookieStore.new
    sso = Debtcollective::SSO.new(user, cookies)

    jwt = sso.generate_jwt

    expect(jwt).not_to be_empty
  end

  it '#set_jwt_cookie' do
    cookies = FakeCookieStore.new
    sso = Debtcollective::SSO.new(user, cookies)

    sso.set_jwt_cookie

    expect(cookies[SiteSetting.sso_cookie_name][:httponly]).to eq(true)
  end

  it '#remove_jwt_cookie' do
    cookies = FakeCookieStore.new
    cookies[SiteSetting.sso_cookie_name] = 'remove-me'
    sso = Debtcollective::SSO.new(user, cookies)

    sso.remove_jwt_cookie

    expect(cookies[SiteSetting.sso_cookie_name]).to be_nil
  end
end
