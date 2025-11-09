class Lead < ApplicationRecord
  belongs_to :campaign
  has_many :agent_outputs, dependent: :destroy

  validates :name, :email, :title, :company, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_save :set_default_website

  # Map camelCase API attribute to snake_case database column
  def campaignId
    campaign_id
  end

  def campaignId=(value)
    self.campaign_id = value
  end

  # Override as_json to maintain API compatibility with camelCase
  def as_json(options = {})
    super(options).merge(
      "campaignId" => campaign_id
    ).except("campaign_id")
  end

  private

  def set_default_website
    self.website = email.split("@")[1] if website.to_s.strip.empty?
  end
end
