# frozen_string_literal: true

module DemandsAggregator
  extend ActiveSupport::Concern

  def average_queue_time
    total_queue_time = demands.kept.map(&:total_queue_time).sum
    total_demands = demands.kept.count

    return 0 if total_queue_time.zero? || total_demands.zero?

    total_queue_time.to_f / total_demands
  end

  def average_touch_time
    total_touch_time = demands.kept.map(&:total_touch_time).sum
    total_demands = demands.kept.count

    return 0 if total_touch_time.zero? || total_demands.zero?

    total_touch_time.to_f / total_demands
  end

  def avg_hours_per_demand
    return 0 unless demands.kept.count.positive?

    demands.kept.map(&:total_effort).compact.sum / demands.kept.count
  end
end