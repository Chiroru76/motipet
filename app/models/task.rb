class Task < ApplicationRecord
  belongs_to :user

  enum :kind, { todo: 0, habit: 1 }, default: :todo
  enum :status, { open: 0, done: 1, archived: 2 }, default: :open
  enum :difficulty, { easy: 0, normal: 1, hard: 2 }, default: :easy
  enum :target_unit, { times: 0, km: 1, minutes: 2, hours: 3, steps: 4, pages: 5, kcal: 6, words: 7, sets: 8, kg: 9 }
  enum :target_period, { daily: 0, weekly: 1, monthly: 2 }
  enum :tracking_mode, { checkbox: 0, log: 1 }

  has_many :task_events, dependent: :destroy

  # 難易度応じた経験値を定義（要調整）
  REWARD_EXP_BY_DIFFICULTY = {
    "easy" => 10,
    "normal" => 20,
    "hard" => 40
  }.freeze
  # 難易度に応じて経験値を自動設定
  before_validation :assign_reward_exp_by_difficulty

  validates :title, presence: true, length: { maximum: 255 }
  validates :difficulty, presence: true
  validates :tag, length: { maximum: 50 }, allow_blank: true
  validates :reward_exp, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :reward_food_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :tracking_mode, presence: true, if: :habit?
  # 位置情報
  validates :location_address, length: { maximum: 255 }, allow_blank: true
  validates :place_id, uniqueness: { scope: :user_id, allow_nil: true }
  # place_idが変更された場合のみジオコーディング実行
  after_validation :geocode_with_error_handling, if: :should_geocode?


  # 作成イベントを明示で残すメソッド
  def log_created!(by_user:)
    task_events.create!(
      user: by_user,
      task_kind: self[:kind], # スナップショットとして整数値を固定
      action: :created,
      delta: 0,
      amount: 0,
      xp_amount: 0,
      occurred_at: Time.current
    )
  end

  # ---- 完了処理（状態変更 + イベント + 必要ならXP付与）----
  def complete!(by_user:, _amount: 0, unit: nil, award_exp: true)
    raise "Only for checkbox habits or todos" if habit? && !checkbox?

    # return self if done? # 二重押下対策（MVP：雑に弾く）

    ApplicationRecord.transaction do
      update!(status: :done, completed_at: Time.current)
      give_food_to_user

      awarded = by_user.active_character
      xp = reward_exp.to_i

      awarded&.gain_exp!(xp) if award_exp && xp.positive?

      task_events.create!(
        user: by_user,
        task_kind: self[:kind],
        action: :completed,
        delta: 1,
        amount: 0,
        unit: unit,
        xp_amount: xp,
        awarded_character: awarded,
        occurred_at: Time.current
      )
    end

    self
  end

  # 数量ログ入力
  def log!(by_user:, amount:, unit:)
    raise "Only for habit log mode" unless habit? && log?

    require "bigdecimal"
    qty = begin
      BigDecimal(amount.to_s)
    rescue StandardError
      0
    end
    unit = unit.presence || target_unit

    ApplicationRecord.transaction do
      give_food_to_user
      awarded = by_user.active_character
      xp = reward_exp.to_i
      awarded&.gain_exp!(xp) if xp.positive?

      task_events.create!(
        user: by_user, task: self, task_kind: :habit, action: :logged,
        delta: 1, amount: qty, unit: unit,
        xp_amount: xp, awarded_character: awarded,
        occurred_at: Time.current
      )
    end
    self
  end

  # ---- 取り消し（openへ戻す + イベント。XP相殺もここで）----
  def reopen!(by_user:, revert_exp: true, revert_food: true)
    return self if open?

    ApplicationRecord.transaction do
      update!(status: :open, completed_at: nil)

      awarded = by_user.active_character
      xp_cancel = -reward_exp.to_i

      awarded.decrease_exp!(xp_cancel.abs) if revert_exp && xp_cancel.negative? && awarded.respond_to?(:decrease_exp!)

      by_user.decrement!(:food_count, reward_food_count) if revert_food && reward_food_count.to_i.positive?

      task_events.create!(
        user: by_user,
        task_kind: self[:kind],
        action: :reopened,
        delta: -1,
        amount: 0,
        xp_amount: xp_cancel,
        awarded_character: awarded,
        occurred_at: Time.current
      )
    end

    self
  end

  private

  def assign_reward_exp_by_difficulty
    return if difficulty.blank?

    # 難易度が変更または未設定の際に経験値を計算
    self.reward_exp = REWARD_EXP_BY_DIFFICULTY.fetch(difficulty.to_s, 0) if will_save_change_to_difficulty? || reward_exp.blank?
  end

  def give_food_to_user
    user.increment!(:food_count, reward_food_count)
  end

  # ---- ジオコーディング関連 ----
  def should_geocode?
    place_id_changed? && place_id.present?
  end

  def geocode_with_error_handling
    begin
      results = Geocoder.search("place_id:#{place_id}")
      if results.present?
        location = results.first
        self.latitude = location.latitude
        self.longitude = location.longitude
        self.location_address = location.address
      else
        errors.add(:base, "指定された場所IDに対応する位置情報が見つかりません。")
      end
    rescue StandardError => e
      errors.add(:base, "ジオコーディング中にエラーが発生しました: #{e.message}")
    end
  end
end
