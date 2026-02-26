module MealPlansHelper
  PARTICIPANT_COLORS = %w[
    #3B82F6
    #EF4444
    #10B981
    #F59E0B
    #8B5CF6
    #EC4899
    #06B6D4
    #F97316
  ].freeze

  def participant_color(index)
    PARTICIPANT_COLORS[index % PARTICIPANT_COLORS.length]
  end

  def macro_status_class(actual, target)
    return "text-gray-500" unless target && target > 0

    ratio = actual.to_f / target
    if ratio >= 0.9 && ratio <= 1.1
      "text-green-600"
    elsif ratio >= 0.75 && ratio <= 1.25
      "text-amber-600"
    else
      "text-red-600"
    end
  end

  CALORIE_STATUS = {
    under: { bg: "bg-blue-100", text: "text-blue-700", border: "border-blue-200", label: "Under" },
    on_target: { bg: "bg-green-100", text: "text-green-700", border: "border-green-200", label: "On Target" },
    over: { bg: "bg-red-100", text: "text-red-700", border: "border-red-200", label: "Over" }
  }.freeze

  def calorie_status(actual, target)
    return nil unless target && target > 0

    ratio = actual.to_f / target
    if ratio <= 0.85
      CALORIE_STATUS[:under]
    elsif ratio <= 1.15
      CALORIE_STATUS[:on_target]
    else
      CALORIE_STATUS[:over]
    end
  end

  def calendar_weeks(days)
    days.sort_by(&:date).each_slice(7).to_a
  end
end
