namespace :nutrition do
  desc "Seed nutrition items and aliases from docs/usda_nutrition_data.json"
  task seed: :environment do
    file_path = Rails.root.join("docs", "usda_nutrition_data.json")
    unless File.exist?(file_path)
      puts "Skipping nutrition seed: #{file_path} not found"
      next
    end

    data = JSON.parse(File.read(file_path))
    foods = data["foods"]

    # Group entries by fdc_id to find canonical items vs implicit aliases
    by_fdc_id = {}
    alias_entries = []

    foods.each do |name, attrs|
      if attrs["_alias_of"].present?
        alias_entries << { name: name, alias_of: attrs["_alias_of"] }
      else
        fdc_id = attrs["fdc_id"]
        by_fdc_id[fdc_id] ||= { attrs: attrs, names: [] }
        by_fdc_id[fdc_id][:names] << name
      end
    end

    created_items = 0
    created_aliases = 0

    # Create NutritionItems and aliases for non-alias entries
    by_fdc_id.each do |fdc_id, entry|
      attrs = entry[:attrs]
      item = NutritionItem.find_or_create_by!(fdc_id: fdc_id) do |ni|
        ni.description = attrs["description"]
        ni.calories = attrs["calories"]
        ni.fat = attrs["fat"]
        ni.protein = attrs["protein"]
        ni.carbs = attrs["carbs"]
        ni.fiber = attrs["fiber"]
        ni.sodium = attrs["sodium"]
        ni.potassium = attrs["potassium"]
        ni.magnesium = attrs["magnesium"]
      end
      created_items += 1 if item.previously_new_record?

      # Create alias for each name pointing to this fdc_id
      entry[:names].each do |name|
        normalized = NutritionItem.normalize_name(name)
        alias_record = NutritionItem::Alias.find_or_create_by!(name: normalized) do |a|
          a.nutrition_item = item
        end
        created_aliases += 1 if alias_record.previously_new_record?
      end
    end

    # Create aliases for _alias_of entries
    alias_entries.each do |entry|
      canonical_name = NutritionItem.normalize_name(entry[:alias_of])
      canonical_alias = NutritionItem::Alias.find_by(name: canonical_name)

      unless canonical_alias
        puts "Warning: canonical item '#{entry[:alias_of]}' not found for alias '#{entry[:name]}'"
        next
      end

      normalized = NutritionItem.normalize_name(entry[:name])
      alias_record = NutritionItem::Alias.find_or_create_by!(name: normalized) do |a|
        a.nutrition_item = canonical_alias.nutrition_item
      end
      created_aliases += 1 if alias_record.previously_new_record?
    end

    puts "Nutrition seed complete: #{created_items} items, #{created_aliases} aliases created"
  end
end
