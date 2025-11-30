# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create or find default Gmail sender user (system account for sending emails)
default_sender_email = ENV.fetch("DEFAULT_GMAIL_SENDER", "campaignsenderagent@gmail.com")
default_sender = User.find_by(email: default_sender_email) || User.create!(
  email: default_sender_email,
  password: Devise.friendly_token[0, 20], # Random password, won't be used for login
  password_confirmation: Devise.friendly_token[0, 20],
  name: "Default Campaign Sender",
  first_name: "Campaign",
  last_name: "Sender",
  workspace_name: "System",
  job_title: "Email Sender"
)
Rails.logger.info("Default Gmail sender user: #{default_sender.email} (ID: #{default_sender.id})")

# Create or find admin user
admin_user = User.find_by(email: 'admin@example.com') || User.create!(
  email: "admin@example.com",
  password: "password123",
  password_confirmation: "password123",
  name: "Admin User",
  first_name: "Admin",
  last_name: "User",
  workspace_name: "Admin Workspace",
  job_title: "Administrator"
)

# Create sample campaign if none exists for admin user
if admin_user.campaigns.count == 0
  campaign = admin_user.campaigns.create!(
    title: 'Tech Startup Outreach Campaign',
    shared_settings: {
      "brand_voice" => {
        "tone" => "professional",
        "persona" => "founder"
      },
      "primary_goal" => "book_call"
    }
  )
  puts "Created campaign: #{campaign.title}"

  # Create default agent configs for the campaign
  [ 'SEARCH', 'WRITER', 'CRITIQUE' ].each do |agent_name|
    default_settings = case agent_name
    when 'SEARCH'
      {
        "search_depth" => "basic",
        "max_queries_per_lead" => 2,
        "extracted_fields" => [
          "company_industry",
          "company_size_range",
          "recent_announcement_or_news",
          "flagship_product_or_service"
        ],
        "on_low_info_behavior" => "generic_industry"
      }
    when 'WRITER'
      {
        "email_length" => "short",
        "personalization_level" => "medium",
        "cta_softness" => "balanced",
        "num_variants_per_lead" => 2
      }
    when 'CRITIQUE'
      {
        "checks" => {
          "check_personalization" => true,
          "check_brand_voice" => true,
          "check_spamminess" => true
        },
        "strictness" => "moderate",
        "rewrite_policy" => "rewrite_if_bad",
        "min_score_for_send" => 6,
        "variant_selection" => "highest_overall_score"
      }
    else
      {}
    end

    campaign.agent_configs.create!(
      agent_name: agent_name,
      enabled: true,
      settings: default_settings
    )
    puts "Created agent config: #{agent_name}"
  end

  # Create sample leads for the campaign
  leads_data = [
    { name: 'Alex Martin', email: 'alex@novacorp.io', title: 'VP Marketing', company: 'NovaCorp', website: 'novacorp.io', stage: 'queued', quality: '-' },
    { name: 'Priya Shah', email: 'priya@orbitai.com', title: 'Head of Demand Gen', company: 'Orbit AI', website: 'orbitai.com', stage: 'queued', quality: '-' },
    { name: 'Daniel Cho', email: 'daniel@stackly.dev', title: 'Growth Lead', company: 'Stackly', website: 'stackly.dev', stage: 'queued', quality: '-' }
  ]

  leads_data.each do |lead_data|
    lead = campaign.leads.create!(lead_data)
    puts "Created lead: #{lead.name} (#{lead.email})"
  end
else
  puts "Admin user already has #{admin_user.campaigns.count} campaign(s)"

  # Update existing campaigns to have shared_settings and agent_configs if missing
  admin_user.campaigns.each do |campaign|
    # Update shared_settings if missing or empty (use read_attribute to check actual DB value)
    db_value = campaign.read_attribute(:shared_settings)
    if db_value.nil? || (db_value.is_a?(Hash) && db_value.empty?)
      campaign.update!(
        shared_settings: {
          "brand_voice" => {
            "tone" => "professional",
            "persona" => "founder"
          },
          "primary_goal" => "book_call"
        }
      )
      puts "Updated shared_settings for campaign: #{campaign.title}"
    end

    # Create missing agent configs
    [ 'SEARCH', 'WRITER', 'CRITIQUE' ].each do |agent_name|
      unless campaign.agent_configs.exists?(agent_name: agent_name)
        default_settings = case agent_name
        when 'SEARCH'
          {
            "search_depth" => "basic",
            "max_queries_per_lead" => 2,
            "extracted_fields" => [
              "company_industry",
              "company_size_range",
              "recent_announcement_or_news",
              "flagship_product_or_service"
            ],
            "on_low_info_behavior" => "generic_industry"
          }
        when 'WRITER'
          {
            "email_length" => "short",
            "personalization_level" => "medium",
            "cta_softness" => "balanced",
            "num_variants_per_lead" => 2
          }
        when 'CRITIQUE'
          {
            "checks" => {
              "check_personalization" => true,
              "check_brand_voice" => true,
              "check_spamminess" => true
            },
            "strictness" => "moderate",
            "rewrite_policy" => "rewrite_if_bad",
            "min_score_for_send" => 6,
            "variant_selection" => "highest_overall_score"
          }
        else
          {}
        end

        campaign.agent_configs.create!(
          agent_name: agent_name,
          enabled: true,
          settings: default_settings
        )
        puts "Created agent config: #{agent_name} for campaign: #{campaign.title}"
      end
    end
  end
end

puts "Seeding completed!"
