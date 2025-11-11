class AddSendFromEmailToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :send_from_email, :string
  end
end
