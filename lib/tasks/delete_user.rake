namespace :users do
  desc "Delete a user and all related data"
  task :delete, [ :email ] => :environment do |_t, args|
    email = args[:email]

    unless email
      puts "Usage: rails users:delete[user@example.com]"
      exit 1
    end

    user = User.find_by(email: email)

    unless user
      puts "User with email '#{email}' not found."
      exit 1
    end

    # Show summary of what will be deleted
    campaigns_count = user.campaigns.count
    leads_count = user.campaigns.joins(:leads).count
    agent_configs_count = user.campaigns.joins(:agent_configs).count
    agent_outputs_count = AgentOutput.joins(lead: :campaign).where(campaigns: { user_id: user.id }).count

    puts "\n" + "="*60
    puts "WARNING: This will permanently delete the following:"
    puts "="*60
    puts "User: #{user.email} (ID: #{user.id})"
    puts "  - Campaigns: #{campaigns_count}"
    puts "  - Leads: #{leads_count}"
    puts "  - Agent Configs: #{agent_configs_count}"
    puts "  - Agent Outputs: #{agent_outputs_count}"
    puts "="*60
    puts "\nThis action CANNOT be undone!"
    print "\nType 'DELETE' to confirm: "

    confirmation = STDIN.gets.chomp

    unless confirmation == "DELETE"
      puts "Deletion cancelled."
      exit 0
    end

    # Delete the user (cascades to all related data)
    puts "\nDeleting user and all related data..."
    user.destroy!

    puts "✓ User and all related data deleted successfully."
  end
end
