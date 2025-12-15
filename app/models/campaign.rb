class Campaign < ApplicationRecord
  belongs_to :user
  has_many :leads, dependent: :destroy
  has_many :agent_configs, dependent: :destroy

  validates :title, presence: true
  validate :shared_settings_min_score_bounds

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

  def shared_settings_min_score_bounds
    return unless shared_settings.is_a?(Hash)
    value = shared_settings["min_score_for_send"] || shared_settings[:min_score_for_send]
    return if value.nil?

    # Accept Integer or numeric string only, reject non-numeric strings
    str = value.is_a?(String) ? value.strip : value
    unless str.is_a?(Integer) || str.to_s.match?(/\A-?\d+\z/)
      errors.add(:shared_settings, "min_score_for_send must be an integer, got #{value.inspect}")
      return
    end

    int_value = str.to_i
    if int_value > 10 || int_value < 0
      errors.add(:shared_settings, "min_score_for_send must be between 0 and 10, got #{int_value}")
    end
  end

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
