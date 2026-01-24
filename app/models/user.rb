class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable,
         :omniauthable, omniauth_providers: [:google_oauth2, :line]
  has_many :tasks, dependent: :destroy
  # 所有しているペット一覧をuser.charactersで参照できる
  has_many :characters, dependent: :destroy
  # 現在育成中のペットをuser.active_characterで参照できる
  belongs_to :active_character, class_name: "Character", foreign_key: "character_id", optional: true
  has_many :task_events, dependent: :destroy
  # ユーザーが獲得した称号一覧をuser.user_titlesで参照できる
  has_many :user_titles, dependent: :destroy
  has_many :titles, through: :user_titles
  # ユーザー作成後にペット作成メソッドを呼ぶ
  after_create_commit :create_initial_character
  # 新規登録時は自動的に確認済みにする
  after_create :skip_confirmation_for_new_users
  # 　uidが存在する場合のみ、その一意性をproviderのスコープ内で確認
  validates :uid, presence: true, uniqueness: { scope: :provider }, if: -> { uid.present? }
  validates :email, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :line_user_id, uniqueness: true, allow_nil: true, length: { maximum: 50 }

  def self.from_omniauth(auth)
    # メール一致 → 同一ユーザー扱い（Google と LINE を統合できる）
    user = User.find_by(email: auth.info.email) if auth.info.email.present?

    # provider + uid で検索
    user ||= User.find_or_initialize_by(provider: auth.provider, uid: auth.uid)

    # 初回ログイン時
    if user.new_record?
      user.name  = auth.info.name
      user.email = auth.info.email.presence || "#{auth.uid}@#{auth.provider}.generated"
      user.password = Devise.friendly_token[0, 20]
      user.skip_confirmation!
    end

    user.save!
    user
  end

  def self.create_unique_string
    SecureRandom.uuid
  end

  # ランキングTOP N ユーザーを取得
  def self.top_users(limit = 1000)
    Rails.cache.fetch("top_users_#{limit}", expires_in: 30.minutes) do
      User.includes(active_character: { character_kind: :character_appearances })
        .joins(:active_character)
        .where(characters: { state: :alive })
        .order("characters.level DESC , characters.exp DESC")
        .limit(limit)
        .to_a
    end
  end

  # 自分の順位を取得
  def ranking_position
    return nil unless active_character&.alive?

    top_list = User.top_users(1000)
    position = top_list.index(self)
    position ? position + 1 : nil
  end

  private

  def create_initial_character
    egg_kind = CharacterKind.find_by!(asset_key: "egg", stage: 0)
    ch = characters.create!(character_kind: egg_kind, state: :alive, last_activity_at: Time.current)
    update!(active_character: ch)
  end

  def skip_confirmation_for_new_users
    confirm unless confirmed?
  end
end
