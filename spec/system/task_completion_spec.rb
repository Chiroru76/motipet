require 'rails_helper'

RSpec.describe 'タスク完了', type: :system do
  let(:user) { create(:user) }

  before do
    setup_master_data
    setup_character_for_user(user)
    # system specではlogin_asを使用
    login_as user, scope: :user
  end

  describe 'TODO完了' do
    let!(:task) { create(:task, :todo, user: user, title: '完了するTODO', difficulty: :normal) }

    it 'TODOを完了すると経験値とエサを獲得する' do
      initial_exp = user.active_character.exp
      initial_food = user.food_count

      visit dashboard_show_path

      # タスク項目内のチェックボックスをクリック
      within("li#task_#{task.id}") do
        find('input[type="checkbox"]').click
      end

      # Turbo Streamでの更新を待つ
      sleep 0.5

      # 経験値・エサが増加
      user.reload
      expect(user.active_character.exp).to be > initial_exp
      expect(user.food_count).to be > initial_food
    end
  end

  describe '習慣（チェックボックス型）完了' do
    let!(:habit) { create(:task, :habit_checkbox, user: user, title: '運動習慣', difficulty: :normal) }

    it '習慣を完了すると経験値とエサを獲得する' do
      initial_exp = user.active_character.exp
      initial_food = user.food_count

      visit dashboard_show_path

      # タスク項目内のチェックボックスをクリック
      within("li#task_#{habit.id}") do
        find('input[type="checkbox"]').click
      end

      # Turbo Streamでの更新を待つ
      sleep 0.5

      user.reload
      expect(user.active_character.exp).to be > initial_exp
      expect(user.food_count).to be > initial_food
    end
  end

  describe '習慣（数量ログ型）記録' do
    let!(:habit) { create(:task, :habit_log, user: user, title: '腕立て伏せ', target_value: 30, target_unit: :times) }

    it '数量を記録すると経験値とエサを獲得する' do
      initial_exp = user.active_character.exp
      initial_food = user.food_count

      visit dashboard_show_path

      # モーダルを開いてフォームに入力
      within("#task_#{habit.id}") do
        # 鉛筆アイコンボタンをクリックしてモーダルを開く
        find('button[aria-label="数量を記録"]').click
      end

      # モーダル内のフォームを操作
      within('[data-modal-target="dialog"]') do
        # フォーム内の数値入力欄に入力
        fill_in 'amount', with: '25'
        # 記録ボタンをクリック
        click_button '記録する'
      end

      # Turbo Streamでの更新を待つ
      sleep 0.5

      user.reload
      expect(user.active_character.exp).to be > initial_exp
      expect(user.food_count).to be > initial_food

      # TaskEventに記録されていることを確認
      event = TaskEvent.where(task: habit, action: :logged).last
      expect(event.amount).to eq(25.0)
    end
  end
end
