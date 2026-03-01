# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth API Response Format', type: :request do
  let(:user) { create(:user) }
  let(:application) { create(:application, user: user) }
  let(:auth_request) { create(:auth_request, application: application, state: 'authorized') }
  let(:auth_token) do
    create(:auth_token,
           application: application,
           request_id: auth_request.request_id,
           token: 'test_access_token',
           refresh_token: 'test_refresh_token',
           access_token_expires_at: 2.hours.from_now,
           refresh_token_expires_at: 7.days.from_now,
           auth_data: {
             'expires_in' => 7200,
             'refresh_expires_in' => 604800,
             'user_info' => {
               'open_id' => 'ou_test123',
               'union_id' => 'on_test456',
               'user_id' => 'test_user_id',
               'name' => '张三',
               'en_name' => 'Zhang San',
               'avatar_url' => 'https://example.com/avatar.jpg',
               'tenant_key' => 'test_tenant'
             }
           })
  end

  describe 'GET /api/v1/auth/token' do
    before { auth_token } # Ensure token is created

    it 'returns standardized OAuth response format' do
      get '/api/v1/auth/token', params: { request_id: auth_request.request_id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      # Verify top-level structure
      expect(json).to include(
        'state' => 'authorized',
        'user_access_token' => 'test_access_token',
        'refresh_token' => 'test_refresh_token',
        'expires_in' => be_a(Integer),
        'refresh_token_expires_in' => be_a(Integer),
        'user_info' => be_a(Hash),
        'message' => 'Authorization completed successfully'
      )

      # Verify user_info structure
      user_info = json['user_info']
      expect(user_info).to include(
        'open_id' => 'ou_test123',
        'union_id' => 'on_test456',
        'user_id' => 'test_user_id',
        'name' => '张三',
        'en_name' => 'Zhang San'
      )

      # Verify expires_in is positive (not expired)
      expect(json['expires_in']).to be > 0
      expect(json['refresh_token_expires_in']).to be > 0
    end

    it 'does NOT include nested auth_data wrapper' do
      get '/api/v1/auth/token', params: { request_id: auth_request.request_id }

      json = JSON.parse(response.body)
      
      # Old format had auth_data wrapper - this should NOT exist
      expect(json).not_to have_key('auth_data')
      
      # Data should be at top level instead
      expect(json).to have_key('user_info')
      expect(json).to have_key('expires_in')
    end

    it 'calculates remaining time until expiration' do
      # Set specific expiration time
      auth_token.update!(access_token_expires_at: 1.hour.from_now)
      
      get '/api/v1/auth/token', params: { request_id: auth_request.request_id }

      json = JSON.parse(response.body)
      
      # expires_in should be approximately 3600 seconds (1 hour)
      expect(json['expires_in']).to be_between(3500, 3600)
    end
  end

  describe 'GET /api/v1/auth/status' do
    before { auth_token }

    it 'returns consistent format with get_token endpoint' do
      get '/api/v1/auth/status', params: { request_id: auth_request.request_id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      # Should include same fields as get_token
      expect(json).to include(
        'request_id' => auth_request.request_id,
        'state' => 'authorized',
        'expired' => false,
        'user_access_token' => 'test_access_token',
        'refresh_token' => 'test_refresh_token',
        'expires_in' => be_a(Integer),
        'refresh_token_expires_in' => be_a(Integer),
        'user_info' => be_a(Hash)
      )
    end

    it 'does NOT include auth_data wrapper in status endpoint' do
      get '/api/v1/auth/status', params: { request_id: auth_request.request_id }

      json = JSON.parse(response.body)
      expect(json).not_to have_key('auth_data')
    end
  end

  describe 'Response format comparison' do
    it 'get_token and get_status return consistent data structure' do
      get '/api/v1/auth/token', params: { request_id: auth_request.request_id }
      token_response = JSON.parse(response.body)

      get '/api/v1/auth/status', params: { request_id: auth_request.request_id }
      status_response = JSON.parse(response.body)

      # Both should have same core fields
      shared_fields = %w[user_access_token refresh_token expires_in refresh_token_expires_in user_info]
      shared_fields.each do |field|
        expect(token_response[field]).to eq(status_response[field])
      end
    end
  end

  describe 'Edge cases' do
    it 'handles missing user_info gracefully' do
      auth_token.update!(auth_data: { 'expires_in' => 7200 })
      
      get '/api/v1/auth/token', params: { request_id: auth_request.request_id }

      json = JSON.parse(response.body)
      expect(json['user_info']).to eq({})
    end

    it 'handles expired tokens correctly' do
      auth_token.update!(access_token_expires_at: 1.hour.ago)
      
      get '/api/v1/auth/token', params: { request_id: auth_request.request_id }

      json = JSON.parse(response.body)
      
      # Expired token should return 0, not negative value
      expect(json['expires_in']).to eq(0)
    end
  end
end
