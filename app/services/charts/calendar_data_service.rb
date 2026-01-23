# frozen_string_literal: true

module Charts
  # カレンダー表示用のデータを取得するサービス
  class CalendarDataService
    def initialize(user:, start_date:)
      @user = user
      @start_date = start_date
    end

    def call
      {
        start_date: @start_date,
        all_events: fetch_events
      }
    end

    private

    def fetch_events
      @user.task_events.where(action: :completed)
    end
  end
end
