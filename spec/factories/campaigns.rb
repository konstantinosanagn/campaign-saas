FactoryBot.define do
  factory :campaign do
    association :user
    title { "Test Campaign" }
    base_prompt { "This is a test campaign prompt for outreach emails." }
  end

  factory :campaign_with_leads, class: Campaign do
    association :user
    title { "Campaign with Leads" }
    base_prompt { "Campaign prompt for testing leads." }

    after(:create) do |campaign|
      create_list(:lead, 3, campaign: campaign)
    end
  end
end
