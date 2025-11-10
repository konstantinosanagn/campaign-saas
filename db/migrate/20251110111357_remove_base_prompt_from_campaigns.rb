class RemoveBasePromptFromCampaigns < ActiveRecord::Migration[8.1]
  def change
    remove_column :campaigns, :base_prompt, :text
  end
end
