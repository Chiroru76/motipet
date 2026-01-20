class RankingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @top_users = User.top_users(50)
    @my_position = current_user.ranking_position
  end
end
