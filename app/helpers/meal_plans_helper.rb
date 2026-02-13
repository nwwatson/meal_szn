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
end
