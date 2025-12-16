class Campaign < ApplicationRecord
  belongs_to :user
  has_many :leads, dependent: :destroy
  has_many :agent_configs, dependent: :destroy

  validates :title, presence: true

  # Default shared_settings structure
  after_initialize :set_default_shared_settings, if: :new_record?

  # Helper methods for shared_settings
  def shared_settings
    value = read_attribute(:shared_settings)
    if value.nil? || (value.is_a?(Hash) && value.empty?)
      {
        "brand_voice" => {
          "tone" => "professional",
          "persona" => "founder"
        },
        "primary_goal" => "book_call"
      }
    else
      value
    end
  end

  def brand_voice
    shared_settings.dig("brand_voice") || {
      "tone" => "professional",
      "persona" => "founder"
    }
  end

  def primary_goal
    shared_settings["primary_goal"] || "book_call"
  end

  private

  def set_default_shared_settings
    return if persisted? # Don't set defaults for existing records

    current_value = read_attribute(:shared_settings)
    if current_value.nil? || (current_value.is_a?(Hash) && current_value.empty?)
      self.shared_settings = {
        "brand_voice" => {
          "tone" => "professional",
          "persona" => "founder"
        },
        "primary_goal" => "book_call"
      }
    end
  end
end
