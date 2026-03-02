module NavigationHelper
  def nav_link_to(name, path, controller_match:, icon: nil)
    active = controller_match.include?(controller_name)

    base = "relative inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium transition-colors duration-150"

    css = if active
      "#{base} text-white nav-link-active"
    else
      "#{base} text-primary-200 hover:text-white"
    end

    link_to path, class: css do
      safe_join([ icon, name ].compact)
    end
  end

  def bottom_nav_tab(name, path, controller_match:, icon:)
    active = controller_match.include?(controller_name)
    color = active ? "text-primary-600" : "text-warm-400"

    link_to path, class: "flex flex-col items-center justify-center min-h-[48px] px-1 #{color} transition-colors duration-150" do
      svg = tag.svg(
        class: "w-5 h-5",
        fill: "none",
        viewBox: "0 0 24 24",
        stroke_width: active ? "2" : "1.5",
        stroke: "currentColor",
        aria: { hidden: true }
      ) { tag.path(stroke_linecap: "round", stroke_linejoin: "round", d: icon) }

      safe_join([ svg, tag.span(name, class: "text-[10px] mt-0.5 font-medium") ])
    end
  end
end
