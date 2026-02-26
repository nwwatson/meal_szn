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

  test "mobile_drawer_link renders active state with bg-white/15" do
    self.stubbed_controller_name = "recipes"
    html = mobile_drawer_link("Recipes", "/recipes", controller_match: %w[recipes], icon: "M12 6v12")

    assert_includes html, "bg-white/15"
    assert_includes html, "Recipes"
  end

  test "mobile_drawer_link renders inactive state" do
    self.stubbed_controller_name = "dashboards"
    html = mobile_drawer_link("Recipes", "/recipes", controller_match: %w[recipes], icon: "M12 6v12")

    assert_not_includes html, "bg-white/15"
    assert_includes html, "text-primary-200"
  end

  test "mobile_drawer_link renders SVG icon when provided" do
    html = mobile_drawer_link("Dashboard", "/", controller_match: %w[other], icon: "M2.25 12l8.954-8.955")

    assert_includes html, "<svg"
    assert_includes html, "M2.25 12l8.954-8.955"
  end

  test "mobile_drawer_link works without icon" do
    html = mobile_drawer_link("Dashboard", "/", controller_match: %w[other])

    assert_not_includes html, "<svg"
    assert_includes html, "Dashboard"
  end
end
