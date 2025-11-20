class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :campaigns, dependent: :destroy

  def self.serialize_from_session(*args)
    super(*args.take(2))
  end

  ###############################################################
  # SMTP EMAIL SENDING FIELDS
  ###############################################################

  # Basic validations (optional but recommended)
  validates :smtp_port, numericality: { allow_nil: true }

  # Return the actual sender email (overrides are optional)
  def effective_email
    send_from_email.presence || email
  end

  # Is SMTP fully configured?
  def smtp_configured?
    smtp_server.present? &&
      smtp_username.present? &&
      smtp_app_password.present?
  end
end
