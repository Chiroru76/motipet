# frozen_string_literal: true

module Charts
  # TODO・習慣の完了実績グラフ用データを取得するサービス
  class CompletionChartService
    def initialize(user:, days: 7)
      @user = user
      @days = days
    end

    def call
      {
        days: @days,
        todo_completed: fetch_todo_completed,
        habit_done: fetch_habit_done,
        tasks: fetch_tasks
      }
    end

    private

    def date_range
      @date_range ||= @days.days.ago.to_date..Date.current
    end

    def fetch_todo_completed
      TaskEvent.where(user: @user, task_kind: :todo, action: :completed)
        .group_by_day(:occurred_at, range: date_range)
        .count
    end

    def fetch_habit_done
      TaskEvent.where(user: @user, task_kind: :habit, action: [:completed, :logged])
        .group_by_day(:occurred_at, range: date_range)
        .count
    end

    def fetch_tasks
      @user.tasks.order(created_at: :desc)
    end
  end
end
