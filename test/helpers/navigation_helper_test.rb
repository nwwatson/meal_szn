require "test_helper"

class NavigationHelperTest < ActionView::TestCase
  include NavigationHelper

  # Stub controller_name for testing active state detection
  attr_accessor :stubbed_controller_name

  def controller_name
    stubbed_controller_name || "dashboards"
  end

  test "nav_link_to renders active state with nav-link-active class" do
    self.stubbed_controller_name = "recipes"
    html = nav_link_to("Recipes", "/recipes", controller_match: %w[recipes])

    assert_includes html, "nav-link-active"
    assert_includes html, "text-white"
    assert_includes html, "Recipes"
  end

  test "nav_link_to renders inactive state without nav-link-active class" do
    self.stubbed_controller_name = "dashboards"
    html = nav_link_to("Recipes", "/recipes", controller_match: %w[recipes])

    assert_not_includes html, "nav-link-active"
    assert_includes html, "text-primary-200"
    assert_includes html, "hover:text-white"
  end

  test "nav_link_to matches multiple controller names" do
    self.stubbed_controller_name = "shopping_lists"
    html = nav_link_to("Meal Plans", "/meal_plans", controller_match: %w[meal_plans shopping_lists])

    assert_includes html, "nav-link-active"
  end

  test "nav_link_to generates correct link path" do
    html = nav_link_to("Dashboard", "/dashboard", controller_match: %w[dashboards])

    assert_includes html, 'href="/dashboard"'
  end

  test "bottom_nav_tab renders active state with primary-600 color" do
    self.stubbed_controller_name = "recipes"
    html = bottom_nav_tab("Recipes", "/recipes", controller_match: %w[recipes], icon: "M12 6v12")

    assert_includes html, "text-primary-600"
    assert_includes html, "Recipes"
    assert_includes html, "<svg"
    assert_includes html, "M12 6v12"
  end

  test "bottom_nav_tab renders inactive state with warm-400 color" do
    self.stubbed_controller_name = "dashboards"
    html = bottom_nav_tab("Recipes", "/recipes", controller_match: %w[recipes], icon: "M12 6v12")

    assert_includes html, "text-warm-400"
    assert_not_includes html, "text-primary-600"
  end

  test "bottom_nav_tab uses thicker stroke for active tab" do
    self.stubbed_controller_name = "recipes"
    html = bottom_nav_tab("Recipes", "/recipes", controller_match: %w[recipes], icon: "M12 6v12")

    assert_includes html, 'stroke_width="2"'
  end

  test "bottom_nav_tab uses thinner stroke for inactive tab" do
    self.stubbed_controller_name = "dashboards"
    html = bottom_nav_tab("Recipes", "/recipes", controller_match: %w[recipes], icon: "M12 6v12")

    assert_includes html, 'stroke_width="1.5"'
  end

  test "bottom_nav_tab renders label in span" do
    html = bottom_nav_tab("Plans", "/plans", controller_match: %w[other], icon: "M6 3v2")

    assert_includes html, "<span"
    assert_includes html, "Plans"
  end

  test "bottom_nav_tab has minimum tap target height" do
    html = bottom_nav_tab("Dashboard", "/", controller_match: %w[dashboards], icon: "M2.25 12l8.954")

    assert_includes html, "min-h-[48px]"
  end
end
