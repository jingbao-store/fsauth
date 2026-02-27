require 'rails_helper'

RSpec.describe "Application SKILL.md", type: :request do
  let(:user) { create(:user) }
  let(:application) { create(:application, user: user) }

  describe "GET /applications/:id/SKILL.md" do
    context "with valid application" do
      it "returns the SKILL.md content" do
        get application_skill_path(application)
        
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("text/markdown")
        expect(response.body).to include("飞书 OAuth 认证集成")
        expect(response.body).to include(application.name)
        expect(response.body).to include(application.id)
      end

      it "includes bash script examples" do
        get application_skill_path(application)
        
        expect(response.body).to include("#!/bin/bash")
        expect(response.body).to include("FSAUTH_BASE=")
        expect(response.body).to include("curl -s -X POST")
      end

      it "includes cURL examples" do
        get application_skill_path(application)
        
        expect(response.body).to include("curl -X POST")
        expect(response.body).to include("/api/v1/auth/request")
        expect(response.body).to include(application.id)
      end

      it "includes API endpoint documentation" do
        get application_skill_path(application)
        
        expect(response.body).to include("API 端点")
        expect(response.body).to include("POST")
        expect(response.body).to include("/api/v1/auth/request")
        expect(response.body).to include("/api/v1/auth/token")
      end

      it "is publicly accessible without authentication" do
        # Make request without authentication
        get application_skill_path(application)
        
        expect(response).to have_http_status(:success)
      end
    end

    context "with non-existent application" do
      it "returns not found status" do
        get "/applications/non-existent-id/SKILL.md"
        
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include("Application not found")
      end
    end
  end

  describe "Application#skill_url" do
    it "generates correct SKILL.md URL without token" do
      url = application.skill_url(base_url: "https://example.com")
      
      expect(url).to eq("https://example.com/applications/#{application.id}/SKILL.md")
      expect(url).not_to include("token=")
    end

    it "uses localhost as fallback" do
      url = application.skill_url
      
      expect(url).to include("http://localhost:3000")
      expect(url).to include("/applications/#{application.id}/SKILL.md")
      expect(url).not_to include("token=")
    end
  end
end
