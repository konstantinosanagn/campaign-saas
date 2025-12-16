class Lead < ApplicationRecord
  belongs_to :campaign
  has_many :agent_outputs, dependent: :destroy

  validates :name, :email, :title, :company, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_save :set_default_website

  # Email status query methods
  def email_sent?
    email_status == "sent"
  end

  def email_sending?
    email_status == "sending"
  end

  def email_failed?
    email_status == "failed"
  end

  def email_not_scheduled?
    email_status == "not_scheduled"
  end

  private

  def set_default_website
    self.website = email.split("@")[1] if website.to_s.strip.empty?
  end
end
