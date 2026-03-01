# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth Token Refresh API', type: :request do
  let(:user) { create(:user) }
  let(:application) { create(:application, user: user) }
  let(:auth_request) { create(:auth_request, application: application, state: 'authorized') }
  let(:auth_token) do
    create(:auth_token,
           application: application,
           request_id: auth_request.request_id,
           token: 'old_access_token',
           refresh_token: 'valid_refresh_token',
           access_token_expires_at: 2.hours.from_now,
           refresh_token_expires_at: 7.days.from_now)
  end

  describe 'POST /api/v1/auth/refresh' do
    context 'with valid parameters' do
      it 'returns bad request when app_id or request_id is missing' do
        post '/api/v1/auth/refresh', params: { app_id: application.id }
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('app_id and request_id are required')
      end

      it 'returns not found when application does not exist' do
        post '/api/v1/auth/refresh', params: { app_id: 'invalid-id', request_id: auth_token.request_id }
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns not found when auth_token does not exist' do
        post '/api/v1/auth/refresh', params: { app_id: application.id, request_id: 'invalid-request-id' }
        expect(response).to have_http_status(:not_found)
      end

      it 'returns unauthorized when refresh_token is expired' do
        auth_token.update!(refresh_token_expires_at: 1.day.ago)

        post '/api/v1/auth/refresh', params: { app_id: application.id, request_id: auth_token.request_id }
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('Refresh token expired or unavailable')
      end

      it 'returns unauthorized when refresh_token is missing' do
        auth_token.update!(refresh_token: nil)

        post '/api/v1/auth/refresh', params: { app_id: application.id, request_id: auth_token.request_id }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with mocked Feishu API' do
      before do
        # Mock FeishuAuthService refresh call
        allow_any_instance_of(FeishuAuthService).to receive(:refresh_user_access_token).and_return(
          access_token: 'new_access_token',
          expires_in: 7200,
          refresh_token: 'new_refresh_token',
          refresh_token_expires_in: 604800
        )
      end

      it 'successfully refreshes token' do
        post '/api/v1/auth/refresh', 
             params: { app_id: application.id, request_id: auth_token.request_id },
             as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['user_access_token']).to eq('new_access_token')
        expect(json['expires_in']).to eq(7200)
        expect(json['message']).to eq('Token refreshed successfully')

        # Verify token was updated in database
        auth_token.reload
        expect(auth_token.token).to eq('new_access_token')
        expect(auth_token.refresh_token).to eq('new_refresh_token')
      end
    end

    context 'when Feishu API fails' do
      before do
        allow_any_instance_of(FeishuAuthService).to receive(:refresh_user_access_token).and_raise(StandardError, 'Token refresh failed')
        allow(Rails.logger).to receive(:error)
      end

      it 'returns unprocessable entity' do
        post '/api/v1/auth/refresh',
             params: { app_id: application.id, request_id: auth_token.request_id },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Token refresh failed')
      end
    end
  end
end
