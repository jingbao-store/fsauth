require 'rails_helper'

RSpec.describe "Applications", type: :request do

  let(:user) { last_or_create(:user) }
  before { sign_in_as(user) }

  describe "GET /applications" do
    it "returns http success" do
      get applications_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /applications/:id" do
    let(:application_record) { create(:application, user: user) }

    it "returns http success" do
      get application_path(application_record)
      expect(response).to be_success_with_view_check('show')
    end
  end

  describe "GET /applications/new" do
    it "returns http success" do
      get new_application_path
      expect(response).to be_success_with_view_check('new')
    end
  end

  describe "GET /applications/:id/edit" do
    let(:application_record) { create(:application, user: user) }

    it "returns http success" do
      get edit_application_path(application_record)
      expect(response).to be_success_with_view_check('edit')
    end
  end

  describe "POST /applications" do
    it "creates a new application" do
      post applications_path, params: { application: attributes_for(:application) }
      expect(response).to be_success_with_view_check
    end
  end


  describe "PATCH /applications/:id" do
    let(:application_record) { create(:application, user: user) }

    it "updates the application" do
      patch application_path(application_record), params: { application: attributes_for(:application) }
      expect(response).to be_success_with_view_check
    end
  end
end
