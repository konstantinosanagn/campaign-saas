FactoryBot.define do
  factory :campaign do
    association :user
    title { "Test Campaign" }
    shared_settings { {
      "brand_voice" => {
        "tone" => "professional",
        "persona" => "founder"
      },
      "primary_goal" => "book_call"
    } }
  end

  factory :campaign_with_leads, class: Campaign do
    association :user
    title { "Campaign with Leads" }
    shared_settings { {
      "brand_voice" => {
        "tone" => "professional",
        "persona" => "founder"
      },
      "primary_goal" => "book_call"
    } }

    after(:create) do |campaign|
      create_list(:lead, 3, campaign: campaign)
    end
  end
end
