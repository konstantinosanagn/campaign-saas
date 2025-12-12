# Step definitions for user_remembered.feature

Given('a user is not signed in') do
  @current_user = nil
  allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(false)
end

Given('a user is signed in') do
  @current_user = FactoryBot.create(:user)
  allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(true)
  allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(@current_user)
end

Given('the user does not have a remember_user_token cookie') do
  @cookies = double('cookies', signed: {}, encrypted: {}, :[] => nil)
  allow_any_instance_of(ApplicationController).to receive(:cookies).and_return(@cookies)
end

Given('the user has a remember_user_token cookie') do
  @cookies = double('cookies', signed: { 'remember_user_token' => 'token' }, encrypted: {}, :[] => 'token')
  allow_any_instance_of(ApplicationController).to receive(:cookies).and_return(@cookies)
end

Given('the user has remember_created_at set in the database') do
  @current_user.update!(remember_created_at: Time.current)
end

Given('the user does not have remember_created_at set in the database') do
  @current_user.update!(remember_created_at: nil)
end

When('the system checks if the user is remembered') do
  controller = Users::RegistrationsController.new
  allow(controller).to receive(:user_signed_in?).and_return(@current_user.present?)
  allow(controller).to receive(:current_user).and_return(@current_user)
  allow(controller).to receive(:cookies).and_return(@cookies)
  @remembered_result = controller.user_remembered?
end

Then('the remembered user result should be {bool}') do |expected|
  expect(@remembered_result).to eq(expected)
end
