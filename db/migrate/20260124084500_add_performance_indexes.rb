# frozen_string_literal: true

class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    # TaskEvents: ユーザーごとのアクション別イベント取得を高速化
    # 使用箇所: グラフ表示、統計集計（完了イベントのみ取得）
    # 例: @user.task_events.where(action: :completed)
    add_index :task_events, [:user_id, :action], name: "idx_task_events_user_action"

    # Tasks: ダッシュボードでのTODO/習慣一覧表示を高速化
    # 使用箇所: DashboardController#show（最も頻繁にアクセスされるページ）
    # 例: current_user.tasks.todo.open.order(created_at: :desc)
    add_index :tasks, [:user_id, :kind, :status], name: "idx_tasks_user_kind_status"

    # Tasks: 期限リマインダー通知の高速化
    # 使用箇所: LineNotifyJob（毎日09:00実行）
    # 例: Task.where(due_on: target_date, status: :open)
    add_index :tasks, [:due_on, :status], name: "idx_tasks_due_status"

    # Characters: 死亡通知ジョブの高速化
    # 使用箇所: BondHpDeadLineNotifyJob（毎日00:00実行）
    # 例: .where(characters: { state: :dead, dead_at: time_range })
    add_index :characters, [:state, :dead_at], name: "idx_characters_state_dead_at"
  end
end
