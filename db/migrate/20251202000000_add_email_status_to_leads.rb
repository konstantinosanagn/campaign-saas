class AddEmailStatusToLeads < ActiveRecord::Migration[8.1]
  def change
    add_column :leads, :email_status, :string, default: "not_scheduled", null: false
    add_column :leads, :last_email_sent_at, :datetime
    add_column :leads, :last_email_error_at, :datetime
    add_column :leads, :last_email_error_message, :text

    # Add index for querying by email status
    add_index :leads, :email_status
  end
end
