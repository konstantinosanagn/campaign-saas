class CreateLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :leads do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :title, null: false
      t.string :company, null: false
      t.string :website
      t.references :campaign, null: false, foreign_key: true
      t.string :stage, default: 'queued'
      t.string :quality, default: '-'

      t.timestamps
    end
    
    add_index :leads, :email
  end
end
