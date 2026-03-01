require 'rails_helper'

RSpec.describe FeishuAuthService, type: :service do
  describe '#initialization' do
    it 'can be initialized' do
      expect { FeishuAuthService.new }.not_to raise_error
    end
    
    it 'accepts custom parameters' do
      service = FeishuAuthService.new(
        app_id: 'test_app_id',
        app_secret: 'test_secret',
        redirect_uri: 'http://test.com/callback'
      )
      expect(service.app_id).to eq('test_app_id')
      expect(service.app_secret).to eq('test_secret')
      expect(service.redirect_uri).to eq('http://test.com/callback')
    end
  end
  
  describe '#authorization_url' do
    it 'generates OAuth authorization URL with offline_access scope' do
      service = FeishuAuthService.new(
        app_id: 'test_app_id',
        redirect_uri: 'http://test.com/callback'
      )
      url = service.authorization_url(state: 'test_state')
      
      expect(url).to include('https://accounts.feishu.cn/open-apis/authen/v1/authorize')
      expect(url).to include('client_id=test_app_id')
      expect(url).to include('state=test_state')
      expect(url).to include('scope=offline_access')
    end
    
    it 'supports custom scopes while ensuring offline_access is included' do
      service = FeishuAuthService.new(
        app_id: 'test_app_id',
        redirect_uri: 'http://test.com/callback'
      )
      url = service.authorization_url(state: 'test_state', scope: 'bitable:app:readonly')
      
      expect(url).to include('scope=bitable%3Aapp%3Areadonly+offline_access')
    end
    
    it 'accepts array of scopes' do
      service = FeishuAuthService.new(
        app_id: 'test_app_id',
        redirect_uri: 'http://test.com/callback'
      )
      url = service.authorization_url(state: 'test_state', scope: ['bitable:app:readonly', 'contact:contact.base:readonly'])
      
      expect(url).to include('offline_access')
      expect(url).to include('bitable')
      expect(url).to include('contact')
    end
    
    it 'does not duplicate offline_access if already present' do
      service = FeishuAuthService.new(
        app_id: 'test_app_id',
        redirect_uri: 'http://test.com/callback'
      )
      url = service.authorization_url(state: 'test_state', scope: 'bitable:app:readonly offline_access')
      
      # Should only have one occurrence of offline_access
      decoded_url = URI.decode_www_form_component(url)
      expect(decoded_url.scan(/offline_access/).count).to eq(1)
    end
  end
end
