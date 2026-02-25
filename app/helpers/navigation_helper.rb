module NavigationHelper
  def nav_link_to(name, path, controller_match:)
    active = controller_match.include?(controller_name)

    css = if active
      "bg-primary-800 text-white rounded-md px-3 py-2 text-sm font-medium"
    else
      "text-primary-100 hover:bg-primary-600 hover:text-white rounded-md px-3 py-2 text-sm font-medium"
    end

    link_to name, path, class: css
  end
end
