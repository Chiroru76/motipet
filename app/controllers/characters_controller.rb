class CharactersController < ApplicationController
  before_action :authenticate_user!

  def index
    @characters = current_user.characters
      .joins(:character_kind)
      .where.not(character_kinds: { stage: "egg" }) # 卵は除く
      .select("DISTINCT ON (character_kinds.id) characters.*")
      .order("character_kinds.id, characters.created_at DESC")
      .includes(:character_kind)
  end

  def show
    @character  = current_user.characters.find(params[:id])
    @appearance = CharacterAppearance.find_by(character_kind: @character.character_kind, pose: :idle)

    # Turbo Frame向けのHTML（<turbo-frame id="character_modal"> ...）を返す
    render partial: "characters/detail_modal",
           locals: { character: @character, appearance: @appearance }
  end

  def feed
    @character = current_user.active_character

    if @character.bond_hp >= @character.bond_hp_max
      flash[:alert] = "ペットの幸せ度は最大です"
    elsif current_user.food_count < 1
      flash[:alert] = "えさがありません"
    elsif @character.feed!(current_user)
      # えさやり成功時のペットの反応を生成
      response = Characters::PetResponseBuilder.new(
        character: @character,
        event_context: { feed: true }
      ).build

      flash[:pet_comment] = response[:comment] if response[:comment].present?
      flash[:notice] = "えさをあげました！"
    end

    respond_to do |format|
      format.html { redirect_to dashboard_show_path }
      format.turbo_stream do
        flash.now[:notice] = flash[:notice] if flash[:notice]
        flash.now[:alert] = flash[:alert] if flash[:alert]
        flash.now[:pet_comment] = flash[:pet_comment] if flash[:pet_comment]
      end
    end
  end

  def reset
    # マスターデータからたまごのCharacterKindを取得
    egg_kind = CharacterKind.find_by!(asset_key: "egg")
    # 新しいたまごを作成
    ch = current_user.characters.create!(
      character_kind: egg_kind,
      state: :alive,
      last_activity_at: Time.current
    )

    # ユーザーの現在育成中ペットをたまごに変更
    current_user.update!(active_character: ch)

    redirect_to welcome_egg_path, notice: "ペットをリセットしました"
  end
end
