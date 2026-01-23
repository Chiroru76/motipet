# frozen_string_literal: true

module ChartsHelper
  # グラフの共通設定を返す
  def default_chart_library_options
    {
      chart: {
        fontFamily: "system-ui, -apple-system, sans-serif",
        toolbar: { show: false }
      },
      dataLabels: { enabled: false },
      stroke: { curve: "smooth", width: 3 }
    }
  end

  # 習慣メトリック用の小さいグラフ設定
  def habit_metric_chart_options
    default_chart_library_options.merge(
      chart: default_chart_library_options[:chart].merge(height: 140),
      grid: {
        show: true,
        borderColor: "#f3f4f6",
        strokeDashArray: 3
      },
      scales: { y: { beginAtZero: true } },
      plugins: { legend: { display: false } }
    )
  end
end
