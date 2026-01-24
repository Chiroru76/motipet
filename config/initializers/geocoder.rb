Geocoder.configure(
  # Google Geocoding API を使用
  lookup: :google,

  # APIキー（サーバー用）
  api_key: ENV.fetch("GOOGLE_MAPS_API_KEY_BACKEND", nil),

  # タイムアウト設定
  timeout: 5,

  # 言語設定
  language: :ja,

  # 地域バイアス（日本優先）
  region: :jp,

  # キャッシング（Redis使用）
  cache: -> { Redis.new(url: ENV.fetch("REDIS_URL", "redis://redis:6379/1")) },
  cache_prefix: "geocoder:",

  # キャッシュ有効期限
  cache_options: {
    expiration: 7.days.to_i,
    race_condition_ttl: 10.seconds
  },

  # リトライ設定
  always_raise: :all,

  # レート制限（1秒あたり50リクエストまで）
  http_headers: {
    "User-Agent" => "MochiPet"
  }
)
