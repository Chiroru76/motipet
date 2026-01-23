# frozen_string_literal: true

module Charts
  # 習慣の数量ログデータを取得するサービス
  class HabitMetricsService
    def initialize(user:, days: 7)
      @user = user
      @days = days
    end

    def call
      {
        task_meta: task_metadata,
        series_by_task: series_data,
        total_by_task: total_data
      }
    end

    private

    def date_range
      @date_range ||= @days.days.ago.beginning_of_day..Time.zone.now
    end

    def log_events
      @log_events ||= TaskEvent.where(
        user_id: @user.id,
        task_kind: :habit,
        action: :logged,
        occurred_at: date_range
      )
    end

    def task_ids
      @task_ids ||= log_events.distinct.pluck(:task_id)
    end

    def tasks
      @tasks ||= Task.where(id: task_ids).index_by(&:id)
    end

    # 各タスクの最新のログイベントのunitを一括取得
    def latest_event_units
      @latest_event_units ||= TaskEvent
        .where(user_id: @user.id, task_kind: :habit, action: :logged, task_id: task_ids)
        .select("DISTINCT ON (task_id) task_id, unit")
        .order("task_id, occurred_at DESC")
        .index_by(&:task_id)
    end

    def task_metadata
      task_ids.to_h do |tid|
        task = tasks[tid]
        latest_event = latest_event_units[tid]
        unit = latest_event&.unit.presence || task&.target_unit.presence || "数量"

        [tid, { title: task&.title || "不明なタスク", unit: unit }]
      end
    end

    def series_data
      # 日別×タスクごとの合計値
      raw = log_events.group_by_day(:occurred_at, range: date_range)
        .group(:task_id)
        .sum(:amount)

      # 整形: { task_id => { date => 合計 } }
      series = Hash.new { |h, k| h[k] = {} }
      raw.each do |(date, tid), sum|
        series[tid][date] = sum
      end
      series
    end

    def total_data
      log_events.group(:task_id).sum(:amount)
    end
  end
end
