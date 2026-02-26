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

  def mobile_drawer_link(name, path, controller_match:, icon: nil)
    active = controller_match.include?(controller_name)

    base = "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors"
    css = if active
      "#{base} bg-white/15 text-white"
    else
      "#{base} text-primary-200 hover:bg-white/10 hover:text-white"
    end

    link_to path, class: css do
      parts = []
      if icon
        parts << tag.svg(
          class: "w-5 h-5",
          fill: "none",
          viewBox: "0 0 24 24",
          stroke_width: "1.5",
          stroke: "currentColor",
          aria: { hidden: true }
        ) { tag.path(stroke_linecap: "round", stroke_linejoin: "round", d: icon) }
      end
      parts << name
      safe_join(parts)
    end
  end
end
