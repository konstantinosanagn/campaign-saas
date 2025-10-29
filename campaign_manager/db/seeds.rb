# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create or find admin user
admin_user = User.find_by(email: 'admin@example.com') || User.create!(
  email: "admin@example.com",
  password: "password123",
  password_confirmation: "password123",
  name: "Admin User"
)

# Create sample campaign if none exists for admin user
if admin_user.campaigns.count == 0
  campaign = admin_user.campaigns.create!(
    title: 'Tech Startup Outreach Campaign',
    base_prompt: 'Generate personalized outreach emails for tech startup leads focusing on growth marketing, demand generation, and VP marketing roles. Target companies like NovaCorp, Orbit AI, and Stackly with personalized messaging based on their company size and industry focus.'
  )
  puts "Created campaign: #{campaign.title}"
  
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
end

puts "Seeding completed!"
