class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns do |t|
      t.string :title, null: false
      t.text :base_prompt, null: false
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end
  end
end
