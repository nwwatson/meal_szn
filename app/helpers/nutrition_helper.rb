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

  DIET_BADGE_STYLES = {
    "keto" => { label: "Keto", bg: "bg-green-100", text: "text-green-800" },
    "low-carb" => { label: "Low-Carb", bg: "bg-teal-100", text: "text-teal-800" },
    "high-protein" => { label: "High-Protein", bg: "bg-blue-100", text: "text-blue-800" },
    "paleo" => { label: "Paleo", bg: "bg-orange-100", text: "text-orange-800" },
    "carnivore" => { label: "Carnivore", bg: "bg-red-100", text: "text-red-800" },
    "mediterranean" => { label: "Mediterranean", bg: "bg-sky-100", text: "text-sky-800" },
    "vegan" => { label: "Vegan", bg: "bg-emerald-100", text: "text-emerald-800" },
    "zone" => { label: "Zone", bg: "bg-violet-100", text: "text-violet-800" },
    "standard" => { label: "Standard", bg: "bg-warm-100", text: "text-warm-800" }
  }.freeze

  DIET_BADGE_ORDER = %w[keto low-carb carnivore high-protein paleo mediterranean vegan zone standard].freeze

  def diet_compatibility_badge(nutrition_data)
    return nil unless nutrition_data&.calories&.positive?

    compatible = if nutrition_data.diet_scores.present?
      nutrition_data.compatible_diets
    else
      calculate_compatible_diets_inline(nutrition_data)
    end

    return nil if compatible.empty?

    badges = DIET_BADGE_ORDER.select { |slug| compatible.include?(slug) }.map do |slug|
      style = DIET_BADGE_STYLES[slug]
      next unless style
      content_tag(:span, style[:label],
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{style[:bg]} #{style[:text]}")
    end.compact

    return nil if badges.empty?
    safe_join(badges, " ")
  end

  def diet_score_badges(nutrition_data)
    return nil unless nutrition_data&.diet_scores.present?

    scores = nutrition_data.diet_scores
    badges = DIET_BADGE_ORDER.filter_map do |slug|
      score = scores[slug].to_f
      next if score < 0.4

      style = DIET_BADGE_STYLES[slug]
      next unless style

      if score >= 0.7
        bg = style[:bg]
        text = style[:text]
      else
        bg = "bg-amber-50"
        text = "text-amber-700"
      end

      content_tag(:span, style[:label],
        class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{bg} #{text}",
        aria: { label: "#{style[:label]}: #{(score * 100).round}% compatible" })
    end

    return nil if badges.empty?
    safe_join(badges, " ")
  end

  def diet_score_breakdown(nutrition_data)
    return nil unless nutrition_data&.diet_scores.present?

    scores = nutrition_data.diet_scores
    rows = DIET_BADGE_ORDER.filter_map do |slug|
      score = scores[slug].to_f
      next if score.zero?

      style = DIET_BADGE_STYLES[slug]
      next unless style

      pct = (score * 100).round

      bar_color = if score >= 0.7
        "bg-green-500"
      elsif score >= 0.4
        "bg-amber-400"
      else
        "bg-warm-300"
      end

      content_tag(:div, class: "flex items-center gap-3 text-sm") do
        content_tag(:span, style[:label], class: "w-28 font-medium text-warm-700 shrink-0") +
        content_tag(:div, class: "flex-1 bg-warm-100 rounded-full h-2 overflow-hidden") do
          content_tag(:div, "", class: "h-full rounded-full #{bar_color} transition-all", style: "width: #{pct}%")
        end +
        content_tag(:span, "#{pct}%", class: "w-10 text-right text-warm-500 tabular-nums shrink-0")
      end
    end

    return nil if rows.empty?
    safe_join(rows)
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

  def calculate_compatible_diets_inline(nutrition_data)
    diets = []
    carb_cal = nutrition_data.net_carbs.to_f * 4
    total_cal = nutrition_data.calories.to_f
    carb_pct = carb_cal / total_cal * 100

    diets << "keto" if carb_pct <= 10
    diets << "low-carb" if carb_pct <= 25 && carb_pct > 10

    protein_pct = nutrition_data.protein.to_f * 4 / total_cal * 100
    diets << "high-protein" if protein_pct >= 30

    diets
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
