class Lead < ApplicationRecord
  belongs_to :campaign
  has_many :agent_outputs, dependent: :destroy

  validates :name, :email, :title, :company, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_save :set_default_website

  private

  def set_default_website
    self.website = email.split("@")[1] if website.to_s.strip.empty?
  end
end
