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
    it 'generates OAuth authorization URL' do
      service = FeishuAuthService.new(
        app_id: 'test_app_id',
        redirect_uri: 'http://test.com/callback'
      )
      url = service.authorization_url(state: 'test_state')
      
      expect(url).to include('https://open.feishu.cn/open-apis/authen/v1/authorize')
      expect(url).to include('app_id=test_app_id')
      expect(url).to include('state=test_state')
    end
  end
end
