FactoryBot.define do
  factory :user do
    email { "user#{rand(10000)}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    name { "Test User" }
    first_name { "Test" }
    last_name { "User" }
    workspace_name { "Test Workspace" }
    job_title { "Test Role" }
  end

  factory :admin_user, class: User do
    email { "admin@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    name { "Admin User" }
    first_name { "Admin" }
    last_name { "User" }
    workspace_name { "Admin Workspace" }
    job_title { "Administrator" }
  end
end
