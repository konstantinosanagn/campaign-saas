FactoryBot.define do
  factory :user do
    email { "user#{rand(10000)}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    name { "Test User" }
  end

  factory :admin_user, class: User do
    email { "admin@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    name { "Admin User" }
  end
end

