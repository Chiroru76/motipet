require 'rails_helper'

RSpec.describe 'キャラクター孵化・進化', type: :system do
  let(:user) { create(:user) }

  before do
    setup_master_data
    setup_character_for_user(user)
    login_as user, scope: :user
  end

  describe 'キャラクター孵化（たまご→子供）' do
    it 'レベル2に達するとたまごが孵化する' do
      character = user.active_character
      egg_kind = CharacterKind.find_by!(asset_key: 'egg', stage: :egg)
      character.update!(
        character_kind: egg_kind,
        level: 1,
        exp: Character.threshold_exp_for_next_level(1) - 5
      )

      # 経験値10のTODOを作成
      task = create(:task, :todo, user: user, difficulty: :easy, reward_exp: 10)

      visit dashboard_show_path

      # タスク項目内のチェックボックスをクリック
      within("li#task_#{task.id}") do
        find('input[type="checkbox"]').click
      end

      # シェア画面へ自動リダイレクト
      character.reload
      expect(page).to have_current_path(share_hatched_path(character_id: character.id))
      expect(page).to have_content('誕生しました')

      click_link 'ダッシュボードへ'

      # ダッシュボードに戻る
      expect(page).to have_current_path(dashboard_show_path)

      # 子供に進化していることを確認
      character.reload
      expect(character.character_kind.stage).to eq('child')
      expect(character.level).to eq(2)
    end
  end

  describe 'キャラクター進化（子供→大人）' do
    it 'レベル10に達すると子供が大人に進化する' do
      child_kind = CharacterKind.find_by!(asset_key: 'green_robo', stage: :child)
      character = user.active_character
      character.update!(
        character_kind: child_kind,
        level: 9,
        exp: Character.threshold_exp_for_next_level(9) - 5
      )

      # 経験値10のTODOを作成
      task = create(:task, :todo, user: user, difficulty: :easy, reward_exp: 10)

      visit dashboard_show_path

      # タスク項目内のチェックボックスをクリック
      within("li#task_#{task.id}") do
        find('input[type="checkbox"]').click
      end

      # シェア画面へ自動リダイレクト
      character.reload
      expect(page).to have_current_path(share_evolved_path(character_id: character.id))
      expect(page).to have_content('進化しました')

      click_link 'ダッシュボードへ'

      # ダッシュボードに戻る
      expect(page).to have_current_path(dashboard_show_path)

      # 大人に進化していることを確認
      character.reload
      expect(character.character_kind.stage).to eq('adult')
      expect(character.level).to eq(10)
    end
  end
end
