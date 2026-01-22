class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [:show, :edit, :update, :destroy, :complete]

  def index
    @tasks = current_user.tasks.order(created_at: :desc)
  end

  def show; end

  def new
    # クエリパラメータ kind を読んで、"todo" か "habit" だけを許可
    kind = params[:kind].to_s.presence_in(%w[todo habit]) || "todo"
    @task = current_user.tasks.new(kind: kind, tracking_mode: (kind == "habit" ? :checkbox : nil))
  end

  def create
    @task = current_user.tasks.new(task_create_params)
    if @task.save
      # 作成イベントを明示で残す
      @task.log_created!(by_user: current_user)

      notice = @task.todo? ? "TODOを作成しました" : "習慣を作成しました"
      redirect_to dashboard_show_path, notice: notice
    else
      flash.now[:alert] = @task.errors.full_messages.join("\n")
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @task.update(task_update_params)
      notice = @task.todo? ? "TODOを更新しました" : "習慣を更新しました"
      redirect_to dashboard_show_path, notice: notice
    else
      flash.now[:alert] = @task.errors.full_messages.join("\n")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @task.destroy
      notice = @task.todo? ? "TODOを削除しました" : "習慣を削除しました"
      redirect_to dashboard_show_path, notice: notice
    else
      flash.now[:alert] = "削除できませんでした"
      render :edit, status: :unprocessable_entity
    end
  end

  def complete
    # タスク完了処理 + ペット進化/孵化判定 + コメント生成 + 称号付与を一括実行
    result = Tasks::Completer.new(@task, current_user).call

    # 進化/孵化時は専用シェアページへ（進化時のキャラクターIDを使用）
    character = current_user.active_character
    return redirect_to share_evolved_path(character_id: character.id), notice: "ペットが進化しました！" if result.evolved?
    return redirect_to share_hatched_path(character_id: character.id), notice: "ペットが生まれました！" if result.hatched?

    # 通常完了時のレスポンス
    respond_to do |format|
      format.html { redirect_to dashboard_show_path, notice: result.notice }
      format.turbo_stream do
        flash.now[:notice] = result.notice
        flash.now[:pet_comment] = result.pet_comment
        @unlocked_titles = result.unlocked_titles
        @appearance = result.appearance
        @task = result.task
      end
    end
  end

  # ✅ 数量ログ型: 1回のログにつき reward_exp を固定付与して履歴を残す
  def log_amount
    @task = current_user.tasks.find(params[:id]) unless defined?(@task)
    return head :unprocessable_entity unless @task.habit? && @task.log?

    # 数量を準備
    qty = begin
      BigDecimal(params[:amount].to_s)
    rescue StandardError
      0
    end
    unit = params[:unit].presence || @task.target_unit

    # 数量ログ記録処理
    result = Tasks::AmountLogger.new(@task, current_user, amount: qty, unit: unit).call

    respond_to do |f|
      f.html { redirect_to dashboard_show_path, notice: result.notice }
      f.turbo_stream do
        flash.now[:notice] = result.notice
        flash.now[:pet_comment] = result.pet_comment
        @appearance = result.appearance
        render locals: { hatched: result.hatched?, evolved: result.evolved? }
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to dashboard_show_path, alert: "記録に失敗しました: #{e.record.errors.full_messages.join(', ')}"
  rescue StandardError => e
    Rails.logger.error("[Tasks#log_amount] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
    redirect_to dashboard_show_path, alert: "想定外のエラーが発生しました"
  end

  private

  def set_task
    @task = current_user.tasks.find(params[:id])
  end

  # 作成時は tracking_mode を許可（habit の時だけ意味を持つ）
  def task_create_params
    params.require(:task).permit(
      :title, :kind, :due_on,
      :reward_exp, :reward_food_count,
      :difficulty, :target_value, :target_unit, :target_period, :tag,
      :tracking_mode,
      :location_enabled, :location_address, :place_id, :latitude, :longitude,
      repeat_rule: { days: [] }
    ).tap { |p| p[:repeat_rule] ||= {} }
  end

  # 更新時は方式変更を禁止（MVPでは tracking_mode は受け取らない）
  def task_update_params
    params.require(:task).permit(
      :title, :due_on,
      :reward_exp, :reward_food_count,
      :difficulty, :target_value, :target_unit, :target_period, :tag,
      :location_enabled, :location_address, :place_id, :latitude, :longitude,
      repeat_rule: { days: [] }
    ).tap { |p| p[:repeat_rule] ||= {} }
  end
end
