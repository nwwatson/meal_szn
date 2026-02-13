require "test_helper"

class User::SettingsTest < ActiveSupport::TestCase
  test "belongs to user" do
    settings = user_settings(:one)
    assert_equal users(:one), settings.user
  end

  test "email_frequency enum" do
    assert_equal %w[never every_4_hours daily weekly], User::Settings.email_frequencies.keys
  end

  test "fixture has never email_frequency" do
    settings = user_settings(:one)
    assert settings.never?
  end

  test "fixture two has daily email_frequency" do
    settings = user_settings(:two)
    assert settings.daily?
  end

  test "timezone returns UTC by default when blank" do
    settings = User::Settings.new
    assert_equal "UTC", settings.timezone
  end

  test "timezone returns stored value when present" do
    settings = user_settings(:one)
    assert_equal "America/New_York", settings.timezone
  end

  test "generates UUID id on create" do
    settings = User::Settings.create!(user: users(:admin))
    assert settings.id.present?
    assert_match(/\A[0-9a-f-]{36}\z/, settings.id)
  end

  test "unit_system enum" do
    assert_equal %w[standard metric], User::Settings.unit_systems.keys
  end

  test "fixture one has standard unit_system" do
    settings = user_settings(:one)
    assert settings.standard?
  end

  test "fixture two has metric unit_system" do
    settings = user_settings(:two)
    assert settings.metric?
  end

  test "default unit_system is standard" do
    settings = User::Settings.new
    assert settings.standard?
  end
end
