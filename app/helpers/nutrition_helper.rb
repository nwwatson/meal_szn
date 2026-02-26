module NutritionHelper
  MACRO_COLORS = {
    fat: "#F59E0B",
    protein: "#14B8A6",
    carbs: "#F87171"
  }.freeze

  MACRO_BG_COLORS = {
    fat: "bg-amber-500",
    protein: "bg-teal-500",
    carbs: "bg-red-400"
  }.freeze

  MACRO_LIGHT_BG = {
    fat: "bg-amber-100",
    protein: "bg-teal-100",
    carbs: "bg-red-100"
  }.freeze

  def macro_donut_chart(fat_g:, protein_g:, carbs_g:, size: 80)
    fat_cal = fat_g.to_f * 9
    protein_cal = protein_g.to_f * 4
    carbs_cal = carbs_g.to_f * 4
    total_cal = fat_cal + protein_cal + carbs_cal

    return empty_donut(size) if total_cal.zero?

    fat_pct = (fat_cal / total_cal * 100).round
    protein_pct = (protein_cal / total_cal * 100).round
    carbs_pct = 100 - fat_pct - protein_pct

    fat_end = fat_pct
    protein_end = fat_end + protein_pct

    content_tag(:div, class: "inline-flex flex-col items-center gap-2") do
      content_tag(:div, "",
        class: "macro-donut rounded-full shrink-0",
        style: "width: #{size}px; height: #{size}px; " \
               "background: conic-gradient(" \
               "#{MACRO_COLORS[:fat]} 0% #{fat_end}%, " \
               "#{MACRO_COLORS[:protein]} #{fat_end}% #{protein_end}%, " \
               "#{MACRO_COLORS[:carbs]} #{protein_end}% 100%);") +
      content_tag(:div, class: "flex gap-3 text-xs") do
        macro_legend_item(:fat, fat_pct) +
        macro_legend_item(:protein, protein_pct) +
        macro_legend_item(:carbs, carbs_pct)
      end
    end
  end

  def macro_progress_bar(actual:, target:, label:, macro_key:, unit: "g")
    color = MACRO_BG_COLORS[macro_key] || "bg-warm-500"
    light = MACRO_LIGHT_BG[macro_key] || "bg-warm-100"
    status = macro_bar_status_class(actual, target)

    pct = target && target > 0 ? [ (actual.to_f / target * 100).round, 100 ].min : 0

    content_tag(:div, class: "flex items-center gap-2 text-xs") do
      content_tag(:span, label, class: "w-12 font-medium text-warm-600 shrink-0") +
      content_tag(:div, class: "flex-1 #{light} rounded-full h-2.5 overflow-hidden") do
        content_tag(:div, "", class: "h-full rounded-full #{status}", style: "width: #{pct}%")
      end +
      content_tag(:span, class: "w-24 text-right text-warm-600 tabular-nums shrink-0") do
        if target && target > 0
          raw("#{actual.is_a?(Float) ? actual.round(1) : actual}#{unit} / #{target.is_a?(Float) ? target.round(1) : target}#{unit}")
        else
          raw("#{actual.is_a?(Float) ? actual.round(1) : actual}#{unit}")
        end
      end
    end
  end

  def diet_compatibility_badge(nutrition_data)
    return nil unless nutrition_data&.calories&.positive?

    carb_cal = nutrition_data.net_carbs.to_f * 4
    total_cal = nutrition_data.calories.to_f

    carb_pct = carb_cal / total_cal * 100

    badges = []
    if carb_pct <= 10
      badges << content_tag(:span, "Keto", class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800")
    elsif carb_pct <= 25
      badges << content_tag(:span, "Low-Carb", class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-teal-100 text-teal-800")
    end

    if nutrition_data.protein.to_f * 4 / total_cal * 100 >= 30
      badges << content_tag(:span, "High-Protein", class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800")
    end

    return nil if badges.empty?
    safe_join(badges, " ")
  end

  def mini_donut_chart(fat_g:, protein_g:, carbs_g:)
    macro_donut_chart(fat_g: fat_g, protein_g: protein_g, carbs_g: carbs_g, size: 48)
  end

  private

  def empty_donut(size)
    content_tag(:div, "",
      class: "rounded-full bg-warm-200 shrink-0",
      style: "width: #{size}px; height: #{size}px;")
  end

  def macro_legend_item(macro, pct)
    content_tag(:span, class: "flex items-center gap-1") do
      content_tag(:span, "", class: "inline-block w-2 h-2 rounded-full", style: "background: #{MACRO_COLORS[macro]}") +
      content_tag(:span, "#{macro.to_s.capitalize} #{pct}%", class: "text-warm-600")
    end
  end

  def macro_bar_status_class(actual, target)
    return "bg-warm-400" unless target && target > 0

    ratio = actual.to_f / target
    if ratio >= 0.9 && ratio <= 1.1
      "bg-green-500"
    elsif ratio >= 0.75 && ratio <= 1.25
      "bg-amber-500"
    else
      "bg-red-400"
    end
  end
end
