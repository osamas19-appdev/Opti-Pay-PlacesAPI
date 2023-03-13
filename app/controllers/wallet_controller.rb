class WalletController < ApplicationController


  def index
    user_id = session.fetch(:user_id)
    @user_name = User.where(:id => user_id).first
    
    matching_cards = UserCard.all
    @list_of_cards = matching_cards.where({ :user_id => user_id })

    if user_id.present?
      render({ :template => "wallet/index.html.erb" })
    else
      redirect_to("/user_sign_in")
    end
  end  

  def search

    require 'date'
    require 'json'
    require "uri"
    require "open-uri"
    require "net/http"

    #Get Place name from Google Places API
    the_merchant_name = params.fetch("merchant_name")
    google_places_api_key = ENV.fetch("PLACES_API_KEY")
    places_url = "https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=#{the_merchant_name}&inputtype=textquery&key=#{google_places_api_key}"

    raw_places_data = URI.open(places_url).read
    parsed_places_data = JSON.parse(raw_places_data)
    results_array = parsed_places_data.fetch("candidates")
    first_result_hash = results_array.at(0)
    returned_place_id = first_result_hash.fetch("place_id")


    places_detail_url = "https://maps.googleapis.com/maps/api/place/details/json?place_id=#{returned_place_id}&key=#{google_places_api_key}"
    raw_places_detail_data = URI.open(places_detail_url).read
    parsed_places_detail_data = JSON.parse(raw_places_detail_data)
    details_results = parsed_places_detail_data.fetch("result")
    returned_place_name = details_results.fetch("name")
    returned_place_address = details_results.fetch("formatted_address")
    

    date_time = Time.now.strftime("%Y-%m-%dT%H:%M:%S")
    
    #Visa API to get MCC
    @merchant = returned_place_name
    
    #Payload for API
    data = {
      "searchOptions": {
        "matchScore": "true",
        "maxRecords": "10",
        "matchIndicators": "true"
      },
      "header": {
        "requestMessageId": "VCO_GMR_001",
        "startIndex": "0",
        "messageDateTime": date_time
      },
      "searchAttrList": {
        "merchantName": returned_place_name,
        "merchantCountryCode": "840"
      },
      "responseAttrList": [
        "GNSTANDARD"
      ]
    }

    data_json = data.to_json

    #Calling Visa API
    response = RestClient::Request.execute(
      method: :post,
      url: "https://sandbox.api.visa.com/merchantsearch/v2/search",
      headers: { "content-type": "json", cdisiAutoGenId: "CDISIVDP97666-1992148876" },
      payload: data_json,
      user: "ZCFYS1NRGMQRO0AEWIEZ21G4kKduo1ILZFQP7TulgDSAPTEAo", 
      password: "40A0n0GL35lH0",
      ssl_client_key: OpenSSL::PKey::RSA.new(File.read("/home/gitpod/key_d090c415-fd84-4a82-a094-e932ef29db4a.pem")),
      ssl_client_cert: OpenSSL::X509::Certificate.new(File.read("/home/gitpod/cert.pem")),

    )

    #Parsing API response to get MCC
    parsed_result = JSON.parse(response)
    search_merchant = parsed_result.fetch("merchantSearchServiceResponse")

    #checking if merchant has category 
    if search_merchant.include? "response"
      search_response = search_merchant.fetch("response").at(0)
      search_response_value = search_response.fetch("responseValues")
      merchant_category_desc = search_response_value.fetch("merchantCategoryCodeDesc")
      primary_mcc = search_response_value.fetch("primaryMerchantCategoryCode")
      all_mcc = search_response_value.fetch("merchantCategoryCode")
      visa_merchant_name = search_response_value.fetch("visaMerchantName")
      category_array = all_mcc
    else
      category_array = nil
    end


    #Getting user associated cards from User_cards table
    the_user_id = session.fetch(:user_id)
    
    card_id_array = Array.new

    UserCard.where({ :user_id => the_user_id }).each do |a_card|
      card_id_array.push(a_card.card_id)
    end
    
    #Finding the card with the highet cashback
    result_array = Array.new

    if category_array != nil
      category_array.each do |a_category|
        Card.where({ :id => card_id_array }).each do |a_card|
          number_of_cartegories = a_card.no_of_cats
          if number_of_cartegories == 999
            the_cashback = a_card.cashback
            the_card = a_card.card_name
          elsif a_category = a_card.cat1
            the_cashback = a_card.cat1_cashback
            the_card = a_card.card_name
            the_category = a_card.cat1
          elsif a_category = a_card.cat2
            the_cashback = a_card.cat2_cashback
            the_card = a_card.card_name
            the_category = a_card.cat2
          elsif a_category = a_card.cat3
            the_cashback = a_card.cat3_cashback
            the_card = a_card.card_name
            the_category = a_card.cat3
          elsif a_category = a_card.cat4
            the_cashback = a_card.cat4_cashback
            the_card = a_card.card_name
            the_category = a_card.cat4
          elsif a_category = a_card.cat5
            the_cashback = a_card.cat5_cashback
            the_card = a_card.card_name
            the_category = a_card.cat5
          elsif a_category = a_card.cat6
            the_cashback = a_card.cat6_cashback
            the_card = a_card.card_name
            the_category = a_card.cat6
          else 
            the_cashback = a_card.cashback
            the_card = a_card.card_name        
          end
          card_result = Hash.new
          card_result.store(:cashbak, the_cashback)
          card_result.store(:card_name, the_card)
          card_result.store(:category, the_category)
          result_array.push(card_result)
        end
      end
    else
      Card.where({ :id => card_id_array }).each do |a_card|
        card_result = Hash.new
        card_result.store(:cashbak, a_card.cashback)
        card_result.store(:card_name, a_card.card_name)
        result_array.push(card_result)
      end
    end
    @maximum_cashback = result_array.max_by { |hash| hash[:cashbak] }[:cashbak]
    selected_card = result_array.max_by { |hash| hash[:cashbak] }[:card_name]
    @selected_cat = result_array.max_by { |hash| hash[:cashbak] }[:category]
    @card = Card.where(:card_name => selected_card).at(0)

    render({ :template => "wallet/search_results.html.erb" })
  end  
end
