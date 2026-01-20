require "rails_helper"

RSpec.describe User, type: :model do
  # ========== アソシエーション ==========
  describe "associations" do
    describe "tasks" do
      it "has_many :tasks の関連を持つこと" do
        user = create(:user)
        task = create(:task, user: user)
        expect(user.tasks).to include(task)
      end

      it "ユーザーが削除されるとtasksも削除されること" do
        user = create(:user)
        create(:task, user: user)

        # active_characterの参照を解除してから削除
        user.update!(active_character: nil)
        expect { user.destroy }.to change { Task.count }.by(-1)
      end
    end

    describe "characters" do
      it "has_many :characters の関連を持つこと" do
        user = create(:user)
        # after_create_commitで1体作成されているため、追加で作成
        character = create(:character, user: user)
        expect(user.characters.count).to be >= 1
        expect(user.characters).to include(character)
      end

      it "ユーザーが削除されるとcharactersも削除されること" do
        user = create(:user)
        character_id = user.characters.first.id

        # active_characterの参照を解除してから削除
        user.update!(active_character: nil)
        user.destroy
        expect(Character.find_by(id: character_id)).to be_nil
      end
    end

    describe "active_character" do
      it "belongs_to :active_character の関連を持つこと (optional)" do
        user = create(:user)
        expect(user.active_character).to be_a(Character)
      end

      it "active_characterがnilでも保存できること" do
        # after_create_commitを避けるため、skipコールバックが必要だが、
        # 代わりに作成後にnilに設定できることを確認
        user = create(:user)
        user.update!(active_character: nil)
        expect(user.active_character).to be_nil
      end
    end

    describe "task_events" do
      it "has_many :task_events の関連を持つこと" do
        user = create(:user)
        task = create(:task, user: user)
        task_event = create(:task_event, user: user, task: task)
        expect(user.task_events).to include(task_event)
      end

      it "ユーザーが削除されるとtask_eventsも削除されること" do
        user = create(:user)
        task = create(:task, user: user)
        create(:task_event, user: user, task: task)

        # active_characterの参照を解除してから削除
        user.update!(active_character: nil)
        expect { user.destroy }.to change { TaskEvent.count }.by(-1)
      end
    end

    describe "user_titles" do
      it "has_many :user_titles の関連を持つこと" do
        user = create(:user)
        title = create(:title)
        user_title = UserTitle.create!(user: user, title: title, unlocked_at: Time.current)
        expect(user.user_titles).to include(user_title)
      end

      it "ユーザーが削除されるとuser_titlesも削除されること" do
        user = create(:user)
        title = create(:title)
        UserTitle.create!(user: user, title: title, unlocked_at: Time.current)

        # active_characterの参照を解除してから削除
        user.update!(active_character: nil)
        expect { user.destroy }.to change { UserTitle.count }.by(-1)
      end
    end

    describe "titles" do
      it "has_many :titles, through: :user_titles の関連を持つこと" do
        user = create(:user)
        title = create(:title)
        UserTitle.create!(user: user, title: title, unlocked_at: Time.current)
        expect(user.titles).to include(title)
      end
    end
  end

  # ========== バリデーション ==========
  describe "validations" do
    describe "uid" do
      it "uidが存在する場合、providerスコープ内で一意である必要があること" do
        create(:user, provider: "google_oauth2", uid: "12345", email: "user1@example.com")
        duplicate = build(:user, provider: "google_oauth2", uid: "12345", email: "user2@example.com")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:uid]).to include("はすでに存在します")
      end

      it "異なるproviderであれば同じuidを許可すること" do
        create(:user, provider: "google_oauth2", uid: "12345", email: "user1@example.com")
        different_provider = build(:user, provider: "line", uid: "12345", email: "user2@example.com")
        expect(different_provider).to be_valid
      end

      it "uidがnilの場合はバリデーションをスキップすること" do
        user = build(:user, uid: nil, provider: nil)
        expect(user).to be_valid
      end
    end

    describe "email" do
      it "必須であること" do
        user = build(:user, email: nil)
        expect(user).not_to be_valid
        # Deviseのエラーメッセージ
        expect(user.errors[:email]).to include("が入力されていません。")
      end

      it "一意である必要があること" do
        create(:user, email: "unique_test@example.com")
        duplicate = build(:user, email: "unique_test@example.com")
        expect(duplicate).not_to be_valid
        # Deviseのエラーメッセージ
        expect(duplicate.errors[:email]).to include("は既に使用されています。")
      end

      it "255文字以下である必要があること" do
        long_email = "#{'a' * 244}@example.com"
        user = build(:user, email: long_email)
        expect(user).not_to be_valid
        expect(user.errors[:email]).to be_present
      end

      it "255文字は許可されること" do
        valid_email = "#{'a' * 243}@example.com"
        user = build(:user, email: valid_email)
        expect(user).to be_valid
      end
    end

    describe "line_user_id" do
      it "一意である必要があること" do
        create(:user, line_user_id: "LINE123", email: "user1@example.com")
        duplicate = build(:user, line_user_id: "LINE123", email: "user2@example.com")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:line_user_id]).to include("はすでに存在します")
      end

      it "nilを許可すること" do
        user = build(:user, line_user_id: nil)
        expect(user).to be_valid
      end

      it "50文字以下である必要があること" do
        user = build(:user, line_user_id: "a" * 51)
        expect(user).not_to be_valid
        expect(user.errors[:line_user_id]).to be_present
      end

      it "50文字は許可されること" do
        user = build(:user, line_user_id: "a" * 50)
        expect(user).to be_valid
      end
    end
  end

  # ========== コールバック ==========
  describe "callbacks" do
    describe "after_create_commit" do
      it "ユーザー作成時に初期キャラクターが作成されること" do
        # マスターデータの準備
        egg_kind = CharacterKind.find_or_create_by!(asset_key: "egg", stage: :egg) do |k|
          k.name = "たまご"
        end

        user = User.create!(
          name: "Test User",
          email: "test_callback@example.com",
          password: "password123"
        )

        expect(user.characters.count).to eq(1)
        character = user.characters.first
        expect(character.character_kind).to eq(egg_kind)
        expect(character.state).to eq("alive")
        expect(user.active_character).to eq(character)
      end
    end
  end

  # ========== クラスメソッド ==========
  describe ".from_omniauth" do
    let(:google_auth) do
      OmniAuth::AuthHash.new({
                               provider: "google_oauth2",
                               uid: "google123",
                               info: {
                                 name: "Google User",
                                 email: "google@example.com"
                               }
                             })
    end

    let(:line_auth) do
      OmniAuth::AuthHash.new({
                               provider: "line",
                               uid: "line456",
                               info: {
                                 name: "LINE User",
                                 email: "line@example.com"
                               }
                             })
    end

    before do
      # マスターデータの準備
      CharacterKind.find_or_create_by!(asset_key: "egg", stage: :egg) do |k|
        k.name = "たまご"
      end
    end

    it "新規ユーザーを作成できること" do
      expect do
        User.from_omniauth(google_auth)
      end.to change { User.count }.by(1)

      user = User.last
      expect(user.provider).to eq("google_oauth2")
      expect(user.uid).to eq("google123")
      expect(user.email).to eq("google@example.com")
      expect(user.name).to eq("Google User")
    end

    it "既存ユーザー(provider + uid)の場合は新規作成しないこと" do
      User.from_omniauth(google_auth)

      expect do
        User.from_omniauth(google_auth)
      end.not_to(change { User.count })
    end

    it "同じemailのユーザーがいる場合は統合すること" do
      # 既存ユーザー(Googleで登録)
      existing_user = User.from_omniauth(google_auth)

      # LINEで同じemailでログイン
      line_auth_same_email = OmniAuth::AuthHash.new({
                                                      provider: "line",
                                                      uid: "line789",
                                                      info: {
                                                        name: "LINE User",
                                                        email: "google@example.com" # 同じemail
                                                      }
                                                    })

      expect do
        User.from_omniauth(line_auth_same_email)
      end.not_to(change { User.count })

      user = User.from_omniauth(line_auth_same_email)
      expect(user.id).to eq(existing_user.id)
    end

    it "emailがない場合は生成されたemailを使用すること" do
      no_email_auth = OmniAuth::AuthHash.new({
                                               provider: "line",
                                               uid: "line999",
                                               info: {
                                                 name: "LINE User No Email",
                                                 email: nil
                                               }
                                             })

      user = User.from_omniauth(no_email_auth)
      expect(user.email).to eq("line999@line.generated")
    end
  end

  describe ".create_unique_string" do
    it "UUID形式の文字列を生成すること" do
      uuid = User.create_unique_string
      expect(uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "呼び出すたびに異なる文字列を生成すること" do
      uuid1 = User.create_unique_string
      uuid2 = User.create_unique_string
      expect(uuid1).not_to eq(uuid2)
    end
  end

  describe ".top_users" do
    before(:all) do
      setup_master_data
    end

    before do
      # テストデータ作成
      @user1 = create(:user)
      @user1.active_character.update!(level: 10, exp: 500, state: :alive)

      @user2 = create(:user)
      @user2.active_character.update!(level: 5, exp: 200, state: :alive)

      @user3 = create(:user)
      @user3.active_character.update!(level: 10, exp: 600, state: :alive)

      @dead_user = create(:user)
      @dead_user.active_character.update!(level: 100, exp: 9999, state: :dead)
    end

    it "レベル・経験値の降順でユーザーを取得すること" do
      top = User.top_users(10)
      expect(top.first).to eq(@user3)  # Lv.10, exp: 600
      expect(top.second).to eq(@user1) # Lv.10, exp: 500
      expect(top.third).to eq(@user2)  # Lv.5, exp: 200
    end

    it "死亡したペットを持つユーザーは除外されること" do
      top = User.top_users(10)
      expect(top).not_to include(@dead_user)
    end

    it "指定した件数まで取得すること" do
      top = User.top_users(2)
      expect(top.size).to eq(2)
    end
  end

  describe "#ranking_position" do
    before(:all) do
      setup_master_data
    end

    before do
      @user1 = create(:user)
      @user1.active_character.update!(level: 10, exp: 500)

      @user2 = create(:user)
      @user2.active_character.update!(level: 5, exp: 200)
    end

    it "自分の順位を取得できること" do
      expect(@user2.ranking_position).to eq(2)
    end

    it "ペットが死亡している場合はnilを返すこと" do
      @user2.active_character.update!(state: :dead)
      expect(@user2.ranking_position).to be_nil
    end
  end

  # ========== 基本動作 ==========
  describe "basic functionality" do
    it "有効なファクトリを持つこと" do
      user = build(:user)
      expect(user).to be_valid
    end

    it "Deviseの認証機能を持つこと" do
      user = create(:user, password: "password123")
      expect(user.valid_password?("password123")).to be true
      expect(user.valid_password?("wrongpassword")).to be false
    end
  end
end
