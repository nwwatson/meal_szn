class DietRegistry
  MACROS_PATH = Rails.root.join("docs/macros.json")

  class << self
    def all_diets
      @all_diets ||= JSON.parse(MACROS_PATH.read).fetch("diets")
    end

    def diet_names
      all_diets.map { |d| d["name"] }
    end

    def find_by_name(name)
      all_diets.find { |d| d["name"] == name }
    end

    def macro_targets_for(diet_name, daily_calories)
      diet = find_by_name(diet_name)
      return nil unless diet && daily_calories

      fat_pct = diet["fat_pct"]
      protein_pct = diet["protein_pct"]
      carbs_pct = diet["carbs_pct"]

      # IIFYM has null percentages
      if fat_pct.nil? || protein_pct.nil? || carbs_pct.nil?
        return { calories: daily_calories, fat_g: nil, protein_g: nil, carbs_g: nil }
      end

      fat_mid = (fat_pct["min"] + fat_pct["max"]) / 2.0
      protein_mid = (protein_pct["min"] + protein_pct["max"]) / 2.0
      carbs_mid = (carbs_pct["min"] + carbs_pct["max"]) / 2.0

      {
        calories: daily_calories,
        fat_g: (daily_calories * fat_mid / 100.0 / 9.0).round(1),
        protein_g: (daily_calories * protein_mid / 100.0 / 4.0).round(1),
        carbs_g: (daily_calories * carbs_mid / 100.0 / 4.0).round(1)
      }
    end
  end
end
