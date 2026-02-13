namespace :recipes do
  desc "Seed recipes from Markdown files in db/seeds/"
  task seed: :environment do
    account = if ENV["ACCOUNT_ID"].present?
      Account.find(ENV["ACCOUNT_ID"])
    else
      Account.first
    end

    unless account
      puts "No account found. Set ACCOUNT_ID or create an account first."
      next
    end

    seeds_dir = Rails.root.join("db", "seeds")
    unless seeds_dir.exist?
      puts "Seeds directory not found: #{seeds_dir}"
      next
    end

    created = 0
    skipped = 0

    seeds_dir.each_child do |category_dir|
      next unless category_dir.directory?

      category = category_dir.basename.to_s.downcase
      next unless Recipe.categories.key?(category)

      category_dir.glob("*.md").sort.each do |file|
        content = File.read(file)
        data = MarkdownRecipeParser.new(content).parse

        next unless data[:title].present?

        recipe = Recipe.find_or_initialize_by(title: data[:title], account: account)

        if recipe.persisted?
          skipped += 1
          next
        end

        recipe.assign_attributes(
          category: category,
          description: data[:description],
          source: data[:source],
          servings: data[:servings],
          prep_time: data[:prep_time],
          cook_time: data[:cook_time]
        )

        recipe.save!

        data[:ingredients].each_with_index do |ing, idx|
          recipe.ingredients.create!(
            name: ing[:name],
            quantity: ing[:quantity],
            unit: ing[:unit],
            display_order: idx
          )
        end

        data[:instructions].each do |inst|
          recipe.instructions.create!(
            step_number: inst[:step_number],
            instruction: inst[:instruction]
          )
        end

        if data[:nutrition].present?
          recipe.create_nutrition_data!(
            **data[:nutrition],
            auto_calculated: false
          )
        end

        data[:tips].each do |tip_text|
          recipe.tips.create!(tip: tip_text)
        end

        created += 1
      end
    end

    puts "Recipe seed complete: #{created} created, #{skipped} skipped (#{created + skipped} total)"
  end
end
