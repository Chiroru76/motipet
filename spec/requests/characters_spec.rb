require "rails_helper"

RSpec.describe "Characters", type: :request do
  before(:all) do
    setup_master_data
  end

  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
    setup_character_for_user(user)
  end

  # ===== GET /characters (index) =====
  describe "GET /characters" do
    context "キャラクター一覧の表示" do
      it "自分のキャラクター一覧を取得できる" do
        # たまご以外のキャラクターを複数作成
        child_kind = CharacterKind.find_by!(stage: :child)
        adult_kind = CharacterKind.find_by!(stage: :adult)

        create(:character, user: user, character_kind: child_kind, level: 5)
        create(:character, user: user, character_kind: adult_kind, level: 15)

        get characters_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include(child_kind.name)
        expect(response.body).to include(adult_kind.name)
      end

      it "たまごは一覧から除外される" do
        egg_kind = CharacterKind.find_by!(stage: :egg)
        create(:character, user: user, character_kind: egg_kind)

        get characters_path

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("たまご")
      end

      it "他人のキャラクターは表示されない" do
        other_user = create(:user)
        setup_character_for_user(other_user)
        child_kind = CharacterKind.find_by!(stage: :child)
        other_char = create(:character, user: other_user, character_kind: child_kind)

        get characters_path

        expect(response).to have_http_status(:success)
        # 自分のキャラクターのみ表示される
        response.parsed_body
        # HTML解析で他人のキャラクターIDが含まれないことを確認
        expect(response.body).not_to include("data-character-id=\"#{other_char.id}\"")
      end

      it "未認証の場合はログインページへリダイレクト" do
        sign_out user

        get characters_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  # ===== GET /characters/:id (show) =====
  describe "GET /characters/:id" do
    context "キャラクター詳細モーダルの表示" do
      it "自分のキャラクターの詳細をパーシャルで取得できる" do
        character = user.active_character

        get character_path(character)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("character_modal")
        expect(response.body).to include(character.character_kind.name)
      end

      it "他人のキャラクターは404エラー" do
        other_user = create(:user)
        setup_character_for_user(other_user)
        other_character = other_user.active_character

        get character_path(other_character)

        # current_user.characters.find で見つからないため404
        expect(response).to have_http_status(404)
      end
    end
  end

  # ===== POST /characters/feed (feed) =====
  describe "POST /characters/feed" do
    context "えさやり機能" do
      it "えさをあげるとbond_hpが増加し、food_countが減少する" do
        character = user.active_character
        user.update!(food_count: 10)
        initial_bond_hp = character.bond_hp
        initial_food_count = user.food_count

        post feed_characters_path

        user.reload
        character.reload

        expect(response).to redirect_to(dashboard_show_path)
        expect(flash[:notice]).to eq("えさをあげました！")
        expect(character.bond_hp).to eq(initial_bond_hp + 10)
        expect(user.food_count).to eq(initial_food_count - 1)
        expect(character.last_activity_at).to be_within(2.seconds).of(Time.current)
      end

      it "bond_hpがbond_hp_maxに達している場合はえさをあげられない" do
        character = user.active_character
        character.update!(bond_hp: character.bond_hp_max)
        user.update!(food_count: 10)

        post feed_characters_path

        expect(response).to redirect_to(dashboard_show_path)
        expect(flash[:alert]).to eq("ペットの幸せ度は最大です")
      end

      it "food_countが0の場合はえさをあげられない" do
        user.update!(food_count: 0)

        post feed_characters_path

        expect(response).to redirect_to(dashboard_show_path)
        expect(flash[:alert]).to eq("えさがありません")
      end

      it "bond_hpがbond_hp_maxを超えないように制限される" do
        character = user.active_character
        character.update!(bond_hp: character.bond_hp_max - 5)
        user.update!(food_count: 10)

        post feed_characters_path

        character.reload

        expect(character.bond_hp).to eq(character.bond_hp_max)
      end
    end

    context "えさやり時のペットコメント生成 (HTML format)" do
      let(:feed_comment) { "おいしかったよ" }

      before do
        user.update!(food_count: 10)
        allow(PetComments::Generator).to receive(:for).and_return(feed_comment)
      end

      it "えさやり時にfeedイベントでコメントが生成されること" do
        expect(PetComments::Generator).to receive(:for).with(
          :feed,
          user: user,
          context: { feed: true }
        )

        post feed_characters_path
      end

      it "生成されたコメントがflashに保存されること" do
        post feed_characters_path
        follow_redirect!

        expect(flash[:pet_comment]).to eq(feed_comment)
      end
    end

    context "えさやり時のペットコメント生成 (Turbo Stream format)" do
      let(:feed_comment) { "ありがとう" }

      before do
        user.update!(food_count: 10)
        allow(PetComments::Generator).to receive(:for).and_return(feed_comment)
      end

      it "えさやり時にfeedイベントでコメントが生成されること" do
        expect(PetComments::Generator).to receive(:for).with(
          :feed,
          user: user,
          context: { feed: true }
        )

        post feed_characters_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      it "Turbo Streamレスポンスにpet_comment_areaが含まれること" do
        post feed_characters_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include("pet_comment_area")
        expect(response.body).to include(feed_comment)
      end

      it "flash.nowにペットコメントが設定されること" do
        post feed_characters_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(controller.flash.now[:pet_comment]).to eq(feed_comment)
      end
    end

    context "えさがない場合はペットコメントを生成しない" do
      before do
        user.update!(food_count: 0)
      end

      it "ペットコメントが生成されないこと" do
        expect(PetComments::Generator).not_to receive(:for)

        post feed_characters_path
      end
    end

    context "幸せ度が最大の場合はペットコメントを生成しない" do
      before do
        user.active_character.update!(bond_hp: user.active_character.bond_hp_max)
        user.update!(food_count: 10)
      end

      it "ペットコメントが生成されないこと" do
        expect(PetComments::Generator).not_to receive(:for)

        post feed_characters_path
      end
    end
  end

  # ===== POST /characters/reset (reset) =====
  describe "POST /characters/reset" do
    context "キャラクターリセット機能" do
      it "新しいたまごを作成し、active_characterを更新する" do
        old_character = user.active_character
        egg_kind = CharacterKind.find_by!(asset_key: "egg", stage: :egg)

        expect do
          post reset_characters_path
        end.to change { user.characters.count }.by(1)

        user.reload
        new_character = user.active_character

        expect(response).to redirect_to(welcome_egg_path)
        expect(flash[:notice]).to eq("ペットをリセットしました")
        expect(new_character).not_to eq(old_character)
        expect(new_character.character_kind).to eq(egg_kind)
        expect(new_character.level).to eq(1)
        expect(new_character.exp).to eq(0)
        expect(new_character.state).to eq("alive")
        expect(new_character.last_activity_at).to be_within(1.second).of(Time.current)
      end

      it "リセット後も古いキャラクターは削除されずに残る" do
        old_character = user.active_character
        old_character_id = old_character.id

        post reset_characters_path

        expect(Character.exists?(old_character_id)).to be true
      end

      it "未認証の場合はログインページへリダイレクト" do
        sign_out user

        post reset_characters_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
