class DashboardController < ApplicationController
  before_action :authenticate_user!
  def show
    @todos = current_user.tasks.todo.open.order(created_at: :desc)
    @habits = current_user.tasks.habit.order(created_at: :desc)

    @character = Character.includes(:character_kind).find_by(id: current_user.character_id)

    @appearance = CharacterAppearance.find_by(
      character_kind: @character&.character_kind,
      pose: :idle
    )
  end
end
