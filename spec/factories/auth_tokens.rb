FactoryBot.define do
  factory :auth_token do
    sequence(:request_id) { |n| SecureRandom.uuid }
    token { SecureRandom.hex(32) }
    auth_data { { user_id: "ou_xxx", refresh_token: "rt_xxx", expires_in: 7200 } }
    used_at { nil }
    
    trait :used do
      used_at { Time.current }
    end
  end
end
