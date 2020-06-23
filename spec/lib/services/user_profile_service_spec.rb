# frozen_string_literal: true
require 'rails_helper'

describe Debtcollective::UserProfileService do
  describe "#add_user_location_data" do
    before do
      @zip_code_user_field = Fabricate(:user_field, name: "Zip Code")
      @state_user_field = Fabricate(:user_field, name: "State")
      @city_user_field = Fabricate(:user_field, name: "City")
      @zip_code = '13617'

      @user = Fabricate(:user,
        email: "test@example.com",
        name: "Bruce Wayne",
        custom_fields: { "user_field_#{@zip_code_user_field.id}": @zip_code }
      )
    end

    it "returns sets user location data using zip code" do
      # Response from the Algolia places API
      query_response = <<-END
      {"hits":[{"country":{"de":"Vereinigte Staaten von Amerika","ru":"Соединённые Штаты Америки","pt":"Estados Unidos da América","it":"Stati Uniti d'America","fr":"États-Unis d'Amérique","hu":"Amerikai Egyesült Államok","es":"Estados Unidos de América","zh":"美国","ar":"الولايات المتّحدة الأمريكيّة","default":"United States of America","ja":"アメリカ合衆国","pl":"Stany Zjednoczone Ameryki","ro":"Statele Unite ale Americii","nl":"Verenigde Staten van Amerika"},"is_country":false,"city":{"default":["Canton"]},"is_highway":false,"importance":17,"_tags":["place/island","country/us","address","source/osm","place"],"postcode":["13617"],"county":{"default":["Saint Lawrence County"],"ru":["округ Сент-Лоренс"]},"population":6076,"country_code":"us","is_city":false,"is_popular":false,"administrative":["New York"],"admin_level":15,"is_suburb":false,"locale_names":{"default":["Willow Island"]},"_geoloc":{"lat":44.5947,"lng":-75.1739},"objectID":"99718134_83903548","_highlightResult":{"country":{"de":{"value":"Vereinigte Staaten von Amerika","matchLevel":"none","matchedWords":[]},"ru":{"value":"Соединённые Штаты Америки","matchLevel":"none","matchedWords":[]},"pt":{"value":"Estados Unidos da América","matchLevel":"none","matchedWords":[]},"it":{"value":"Stati Uniti d'America","matchLevel":"none","matchedWords":[]},"fr":{"value":"États-Unis d'Amérique","matchLevel":"none","matchedWords":[]},"hu":{"value":"Amerikai Egyesült Államok","matchLevel":"none","matchedWords":[]},"es":{"value":"Estados Unidos de América","matchLevel":"none","matchedWords":[]},"zh":{"value":"美国","matchLevel":"none","matchedWords":[]},"ar":{"value":"الولايات المتّحدة الأمريكيّة","matchLevel":"none","matchedWords":[]},"default":{"value":"United States of America","matchLevel":"none","matchedWords":[]},"ja":{"value":"アメリカ合衆国","matchLevel":"none","matchedWords":[]},"pl":{"value":"Stany Zjednoczone Ameryki","matchLevel":"none","matchedWords":[]},"ro":{"value":"Statele Unite ale Americii","matchLevel":"none","matchedWords":[]},"nl":{"value":"Verenigde Staten van Amerika","matchLevel":"none","matchedWords":[]}},"city":{"default":[{"value":"Canton","matchLevel":"none","matchedWords":[]}]},"postcode":[{"value":"<em>13617</em>","matchLevel":"full","fullyHighlighted":true,"matchedWords":["13617"]}],"county":{"default":[{"value":"Saint Lawrence County","matchLevel":"none","matchedWords":[]}],"ru":[{"value":"округ Сент-Лоренс","matchLevel":"none","matchedWords":[]}]},"administrative":[{"value":"New York","matchLevel":"none","matchedWords":[]}],"locale_names":{"default":[{"value":"Willow Island","matchLevel":"none","matchedWords":[]}]}}}],"nbHits":1,"processingTimeMS":28,"query":"13617","params":"query=13617&type=address&restrictSearchableAttributes=postcode&hitsPerPage=1","degradedQuery":false}
      END

      stub_request(:post, "https://places-dsn.algolia.net/1/places/query").
        with(
        body: "{\"query\":\"#{@zip_code}\",\"type\":\"address\",\"restrictSearchableAttributes\":\"postcode\",\"hitsPerPage\":1}",
        headers: {
        'Accept' => 'application/json',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Content-Type' => 'application/json',
        'Host' => 'places-dsn.algolia.net',
        'User-Agent' => 'Ruby',
        'X-Algolia-Api-Key' => '',
        'X-Algolia-Application-Id' => ''
      }).to_return(status: 200, body: query_response, headers: {})

      Debtcollective::UserProfileService.add_user_location_data(@user)
      tdc_user_location = JSON.parse(@user.custom_fields['tdc_user_location'])

      expect(tdc_user_location['state']).to eq('New York')
      expect(tdc_user_location['city']).to eq('Canton')
      expect(tdc_user_location['zip_code']).to eq('13617')
      expect(tdc_user_location['postcodes']).to include('13617')
      expect(tdc_user_location['geoloc']).to eq({ "lat" => 44.5947, "lng" => -75.1739 })
      expect(@user.user_fields[@state_user_field.id.to_s]).to eq('New York')
      expect(@user.user_fields[@city_user_field.id.to_s]).to eq('Canton')
    end
  end

  describe "#add_user_to_state_group" do
    it 'adds user to specific group given their US state' do
      # create user custom field
      user_field = UserField.create({
        name: "State",
        description: "State",
        field_type: "state",
        required: true,
        editable: true,
        show_on_profile: false,
        show_on_user_card: false,
      })
      # create New York group
      state = "New York"
      group = Fabricate(:group, name: "NewYork", full_name: "New York members")
      # create user with State == New York
      user = Fabricate(:user, custom_fields: { "user_field_#{user_field.id}": state })

      Debtcollective::UserProfileService.add_user_to_state_group(user)

      group.reload
      expect(group.users).to include(user)
    end
  end
end
