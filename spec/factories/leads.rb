FactoryBot.define do
  factory :lead do
    association :campaign
    name { "John Doe" }
    email { "john@example.com" }
    title { "VP Marketing" }
    company { "Example Corp" }
    website { "example.com" }
    stage { "queued" }
    quality { "-" }
  end

  factory :lead_without_website, class: Lead do
    association :campaign
    name { "Jane Smith" }
    email { "jane@testcompany.com" }
    title { "Head of Sales" }
    company { "Test Company" }
    website { "" }
    stage { "queued" }
    quality { "-" }
  end
end

