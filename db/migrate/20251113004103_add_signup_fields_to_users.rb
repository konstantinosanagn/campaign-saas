class AddSignupFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :first_name, :string, null: true
    add_column :users, :last_name, :string, null: true
    add_column :users, :workspace_name, :string, null: true
    add_column :users, :job_title, :string, null: true
  end
end
