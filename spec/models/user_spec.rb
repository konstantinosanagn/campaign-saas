require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:campaigns).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:password) }
  end

  describe 'Devise configuration' do
    it 'should be database authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'should be registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'should be recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'should be rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'should be validatable' do
      expect(User.devise_modules).to include(:validatable)
    end
  end

  describe 'creation' do
    it 'creates a valid user' do
      user = build(:user)
      expect(user).to be_valid
      expect(user.save).to be true
    end

    it 'requires email' do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it 'requires password' do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'requires password confirmation' do
      user = build(:user, password: 'password123', password_confirmation: 'different')
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to be_present
    end

    it 'requires valid email format' do
      user = build(:user, email: 'invalid-email')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it 'requires unique email' do
      create(:user, email: 'test@example.com')
      duplicate_user = build(:user, email: 'test@example.com')
      expect(duplicate_user).not_to be_valid
      expect(duplicate_user.errors[:email]).to be_present
    end

    it 'is case-insensitive for email uniqueness' do
      create(:user, email: 'test@example.com')
      duplicate_user = build(:user, email: 'TEST@EXAMPLE.COM')
      expect(duplicate_user).not_to be_valid
      expect(duplicate_user.errors[:email]).to be_present
    end
  end

  describe 'campaigns association' do
    let(:user) { create(:user) }

    it 'can have multiple campaigns' do
      campaign1 = create(:campaign, user: user)
      campaign2 = create(:campaign, user: user)

      expect(user.campaigns.count).to eq(2)
      expect(user.campaigns).to include(campaign1, campaign2)
    end

    it 'destroys associated campaigns when user is destroyed' do
      campaign = create(:campaign, user: user)
      user_id = user.id
      campaign_id = campaign.id

      user.destroy

      expect(Campaign.find_by(id: campaign_id)).to be_nil
      expect(User.find_by(id: user_id)).to be_nil
    end
  end
end
