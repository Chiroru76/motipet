class RankingsController < ApplicationController
  before_action :authenticate_user!

  def show
    # 全ユーザーをキャッシュから取得して配列ページネーション
    all_users = User.top_users
    @top_users = Kaminari.paginate_array(all_users).page(params[:page]).per(10)
    @my_position = current_user.ranking_position
  end
end
