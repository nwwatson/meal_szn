module RecipesHelper
  CATEGORY_VISUALS = {
    "breakfast" => { gradient: "from-amber-300 via-orange-300 to-yellow-200", icon: "sunrise" },
    "lunch"     => { gradient: "from-lime-300 via-emerald-300 to-teal-200", icon: "leaf" },
    "dinner"    => { gradient: "from-rose-400 via-red-300 to-orange-200", icon: "flame" },
    "sides"     => { gradient: "from-stone-300 via-amber-200 to-yellow-100", icon: "grid" },
    "snacks"    => { gradient: "from-violet-300 via-pink-300 to-fuchsia-200", icon: "zap" },
    "sauces"    => { gradient: "from-red-400 via-orange-300 to-amber-200", icon: "droplet" }
  }.freeze

  def recipe_card_banner(recipe, height: "h-36")
    visuals = CATEGORY_VISUALS[recipe.category] || CATEGORY_VISUALS["dinner"]

    if recipe.image.attached?
      content_tag(:div, class: "relative #{height} overflow-hidden") do
        image_tag(recipe.image.variant(resize_to_fill: [ 600, 300 ]),
          class: "w-full h-full object-cover",
          loading: "lazy",
          alt: recipe.title) +
        content_tag(:div, "", class: "absolute inset-0 bg-gradient-to-t from-black/20 to-transparent")
      end
    else
      content_tag(:div, class: "relative #{height} bg-gradient-to-br #{visuals[:gradient]} overflow-hidden") do
        category_pattern(recipe.category) +
        category_icon_svg(visuals[:icon])
      end
    end
  end

  def recipe_show_banner(recipe)
    visuals = CATEGORY_VISUALS[recipe.category] || CATEGORY_VISUALS["dinner"]

    if recipe.image.attached?
      content_tag(:div, class: "relative h-64 sm:h-80 overflow-hidden rounded-t-lg") do
        image_tag(recipe.image.variant(resize_to_fill: [ 1200, 500 ]),
          class: "w-full h-full object-cover",
          alt: recipe.title) +
        content_tag(:div, "", class: "absolute inset-0 bg-gradient-to-t from-black/30 to-transparent")
      end
    else
      content_tag(:div, class: "relative h-48 sm:h-56 bg-gradient-to-br #{visuals[:gradient]} overflow-hidden rounded-t-lg") do
        category_pattern(recipe.category) +
        category_icon_svg(visuals[:icon], size: "w-20 h-20", opacity: "opacity-20")
      end
    end
  end

  private

  def category_pattern(category)
    pattern = case category
    when "breakfast", "snacks"
      "radial-gradient(circle, currentColor 1px, transparent 1px)"
    when "lunch", "sides"
      "repeating-linear-gradient(45deg, transparent, transparent 8px, currentColor 8px, currentColor 9px)"
    else
      "repeating-linear-gradient(-45deg, transparent, transparent 10px, currentColor 10px, currentColor 11px)"
    end

    content_tag(:div, "", class: "absolute inset-0 opacity-[0.07] text-warm-900",
      style: "background-image: #{pattern}; background-size: 20px 20px;")
  end

  def category_icon_svg(icon, size: "w-12 h-12", opacity: "opacity-15")
    content_tag(:div, class: "absolute inset-0 flex items-center justify-center") do
      content_tag(:svg, class: "#{size} #{opacity} text-warm-900", fill: "none",
        stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width" => "1.5") do
        raw(icon_path(icon))
      end
    end
  end

  def icon_path(icon)
    case icon
    when "sunrise"
      '<path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2m0 0a5 5 0 015 5H7a5 5 0 015-5zm-9 7h18M4 15h16M6 19h12"/>'
    when "leaf"
      '<path stroke-linecap="round" stroke-linejoin="round" d="M12 21c-4-4-8-8-8-13a8 8 0 0116 0c0 5-4 9-8 13z"/><path stroke-linecap="round" stroke-linejoin="round" d="M12 21V8"/>'
    when "flame"
      '<path stroke-linecap="round" stroke-linejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.047 6.51 6.51 0 009 11.5a3 3 0 106 0c0-1.12-.492-2.126-1.27-2.812A5.99 5.99 0 0115.362 5.214z"/>'
    when "grid"
      '<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"/>'
    when "zap"
      '<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z"/>'
    when "droplet"
      '<path stroke-linecap="round" stroke-linejoin="round" d="M12 21a7 7 0 007-7c0-3.87-7-13-7-13S5 10.13 5 14a7 7 0 007 7z"/>'
    end
  end
end
