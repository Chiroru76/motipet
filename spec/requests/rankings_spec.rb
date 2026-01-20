require "rails_helper"

RSpec.describe "Rankings", type: :request do
  before(:all) do
    setup_master_data
  end

  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
    setup_character_for_user(user)
  end

  describe "GET /rankings" do
    it "ランキングページを表示できる" do
      get rankings_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("ランキング")
    end

    it "未認証の場合はログインページへリダイレクト" do
      sign_out user
      get rankings_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
