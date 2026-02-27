FactoryBot.define do
  factory :application do
    association :user
    name { "Test Application" }
    feishu_app_id { "cli_#{SecureRandom.hex(10)}" }
    feishu_app_secret { SecureRandom.hex(20) }
  end
end
