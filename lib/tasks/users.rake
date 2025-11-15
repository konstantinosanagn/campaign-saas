namespace :users do
  desc "List users with missing signup fields"
  task list_missing_fields: :environment do
    puts "Users with missing first_name, last_name, workspace_name, or job_title:"
    puts "=" * 80
    
    User.all.each do |u|
      missing = []
      missing << "first_name" if u.first_name.blank?
      missing << "last_name" if u.last_name.blank?
      missing << "workspace_name" if u.workspace_name.blank?
      missing << "job_title" if u.job_title.blank?
      
      if missing.any?
        campaign_count = u.campaigns.count
        lead_count = u.campaigns.sum { |c| c.leads.count }
        puts "ID: #{u.id}, Email: #{u.email}"
        puts "  Missing fields: #{missing.join(', ')}"
        puts "  Campaigns: #{campaign_count}, Leads: #{lead_count}"
        puts ""
      end
    end
  end

  desc "Delete users with missing signup fields (only if they have no campaigns or leads)"
  task delete_orphaned: :environment do
    puts "Deleting users with missing signup fields that have no campaigns or leads..."
    puts "=" * 80
    
    deleted_count = 0
    
    User.all.each do |u|
      missing = []
      missing << "first_name" if u.first_name.blank?
      missing << "last_name" if u.last_name.blank?
      missing << "workspace_name" if u.workspace_name.blank?
      missing << "job_title" if u.job_title.blank?
      
      if missing.any?
        campaign_count = u.campaigns.count
        lead_count = u.campaigns.sum { |c| c.leads.count }
        
        if campaign_count == 0 && lead_count == 0
          puts "Deleting user ID: #{u.id}, Email: #{u.email} (no campaigns or leads)"
          u.destroy
          deleted_count += 1
        else
          puts "Skipping user ID: #{u.id}, Email: #{u.email} (has #{campaign_count} campaigns, #{lead_count} leads)"
        end
      end
    end
    
    puts ""
    puts "Deleted #{deleted_count} users."
  end

  desc "Delete users with missing signup fields (FORCE - deletes even if they have campaigns/leads)"
  task delete_all_missing: :environment do
    puts "WARNING: This will delete ALL users with missing signup fields, including those with campaigns/leads!"
    puts "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
    sleep 5
    
    puts "Deleting users with missing signup fields..."
    puts "=" * 80
    
    deleted_count = 0
    
    User.all.each do |u|
      missing = []
      missing << "first_name" if u.first_name.blank?
      missing << "last_name" if u.last_name.blank?
      missing << "workspace_name" if u.workspace_name.blank?
      missing << "job_title" if u.job_title.blank?
      
      if missing.any?
        campaign_count = u.campaigns.count
        lead_count = u.campaigns.sum { |c| c.leads.count }
        puts "Deleting user ID: #{u.id}, Email: #{u.email} (#{campaign_count} campaigns, #{lead_count} leads)"
        u.destroy
        deleted_count += 1
      end
    end
    
    puts ""
    puts "Deleted #{deleted_count} users."
  end
end

