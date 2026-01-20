require 'rails_helper'

RSpec.describe 'ランキング表示', type: :system do
  let(:user) { create(:user) }

  before do
    setup_master_data
    setup_character_for_user(user)
    login_as user, scope: :user
  end

  describe 'ランキングページ' do
    before do
      @top_user = create(:user)
      @top_user.active_character.update!(level: 50, exp: 10_000)

      user.active_character.update!(level: 5, exp: 100)
    end

    it 'ランキングリストが表示される' do
      visit rankings_path

      expect(page).to have_content('ランキング')
      expect(page).to have_content(@top_user.name)
      expect(page).to have_content('Lv.50')
    end

    it '自分の順位がハイライト表示される' do
      visit rankings_path

      expect(page).to have_content('あなたの順位')
      expect(page).to have_content(user.name)
    end

    it '死亡ペットのユーザーは表示されない' do
      dead_user = create(:user)
      dead_user.active_character.update!(level: 100, exp: 99_999, state: :dead)

      visit rankings_path

      expect(page).not_to have_content(dead_user.name)
    end
  end
end
