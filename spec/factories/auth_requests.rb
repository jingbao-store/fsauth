FactoryBot.define do
  factory :auth_request do
    sequence(:request_id) { |n| SecureRandom.uuid }
    state { "pending" }
    expires_at { 10.minutes.from_now }
    association :application
    
    trait :expired do
      expires_at { 1.hour.ago }
    end
    
    trait :authorized do
      state { "authorized" }
    end
    
    trait :failed do
      state { "failed" }
    end
  end
end
