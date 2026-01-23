class ChartsController < ApplicationController
  before_action :authenticate_user!

  def show
    # 日数パラメータ取得（7日 or 30日）
    days = %w[7 30].include?(params[:range]) ? params[:range].to_i : 7

    # 完了実績グラフ用データ
    completion_data = Charts::CompletionChartService.new(user: current_user, days: days).call
    @days = completion_data[:days]
    @todo_completed = completion_data[:todo_completed]
    @habit_done = completion_data[:habit_done]
    @tasks = completion_data[:tasks]

    # 習慣の数量ログデータ
    habit_metrics = Charts::HabitMetricsService.new(user: current_user, days: 7).call
    @task_meta = habit_metrics[:task_meta]
    @series_by_task = habit_metrics[:series_by_task]
    @total_by_task = habit_metrics[:total_by_task]

    # カレンダーデータ
    raw_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Time.zone.today
    start_date = raw_date.beginning_of_month
    calendar_data = Charts::CalendarDataService.new(user: current_user, start_date: start_date).call
    @start_date = calendar_data[:start_date]
    @all_events = calendar_data[:all_events]

    respond_to do |format|
      format.html

      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "calendar",
          partial: "calendar"
        )
      end
    end

    render :show
  end
end
