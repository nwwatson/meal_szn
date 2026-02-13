class MarkdownRecipeParser
  UNIT_NORMALIZATION = {
    "tablespoon" => "tbsp", "tablespoons" => "tbsp",
    "teaspoon" => "tsp", "teaspoons" => "tsp",
    "cup" => "cups", "cups" => "cups",
    "ounce" => "oz", "ounces" => "oz",
    "pound" => "lb", "pounds" => "lb",
    "clove" => "clove", "cloves" => "clove",
    "slice" => "slice", "slices" => "slice",
    "piece" => "piece", "pieces" => "piece",
    "pinch" => "pinch",
    "dash" => "dash"
  }.freeze

  COUNT_WORDS = %w[large medium small].freeze

  KNOWN_UNITS = (UNIT_NORMALIZATION.keys + COUNT_WORDS).freeze

  NUTRITION_KEY_MAP = {
    "calories" => :calories,
    "fat" => :fat,
    "protein" => :protein,
    "total carbs" => :carbs,
    "fiber" => :fiber,
    "sodium" => :sodium,
    "potassium" => :potassium,
    "magnesium" => :magnesium
  }.freeze

  def initialize(content)
    @content = content
  end

  def parse
    lines = @content.lines.map(&:rstrip)
    sections = extract_sections(lines)

    {
      title: extract_title(lines),
      description: extract_description(lines),
      source: sections["Source"]&.strip,
      servings: parse_servings(sections["Servings"]),
      prep_time: parse_time(sections["Prep Time"]),
      cook_time: parse_time(sections["Cook Time"]),
      ingredients: parse_ingredients(sections["Ingredients"]),
      instructions: parse_instructions(sections["Instructions"]),
      nutrition: parse_nutrition(sections["Nutrition (per serving)"]),
      tips: parse_tips(sections["Tips"])
    }
  end

  private

  def extract_title(lines)
    title_line = lines.find { |l| l.start_with?("# ") && !l.start_with?("## ") }
    title_line&.sub(/^# /, "")&.strip
  end

  def extract_description(lines)
    title_index = lines.index { |l| l.start_with?("# ") && !l.start_with?("## ") }
    return nil unless title_index

    first_section = lines.index { |l| l.start_with?("## ") }
    return nil unless first_section

    desc_lines = lines[(title_index + 1)...first_section]
    desc = desc_lines.map(&:strip).reject(&:empty?).join(" ")
    desc.empty? ? nil : desc
  end

  def extract_sections(lines)
    sections = {}
    current_header = nil
    current_content = []

    lines.each do |line|
      if line.match?(/^## /)
        if current_header
          sections[current_header] = current_content.join("\n")
        end
        current_header = line.sub(/^## /, "").strip
        current_content = []
      elsif current_header
        current_content << line
      end
    end

    sections[current_header] = current_content.join("\n") if current_header
    sections
  end

  def parse_servings(text)
    return nil if text.blank?
    match = text.strip.match(/\A(\d+)/)
    match ? match[1].to_i : nil
  end

  def parse_time(text)
    return nil if text.blank?
    # Only parse the main value before any parenthetical
    primary = text.strip.split("(").first.strip

    if primary.match?(/hour/i)
      match = primary.match(/(\d+)\s*hour/i)
      return match ? match[1].to_i * 60 : nil
    end

    match = primary.match(/(\d+)/)
    match ? match[1].to_i : nil
  end

  def parse_ingredients(text)
    return [] if text.blank?

    text.lines.filter_map { |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      raw = line.sub(/^-\s*/, "")
      parse_ingredient_line(raw)
    }
  end

  def parse_ingredient_line(raw)
    # Try to match a leading quantity (number, fraction, or mixed number)
    quantity_pattern = /\A(\d+\s+\d+\/\d+|\d+\/\d+|\d+(?:\.\d+)?)\s+/
    match = raw.match(quantity_pattern)

    unless match
      # Check for unit words at the start (e.g., "Pinch sea salt")
      word = raw.split(/\s+/, 2).first&.downcase
      if UNIT_NORMALIZATION.key?(word)
        normalized = UNIT_NORMALIZATION[word]
        rest = raw.split(/\s+/, 2).last
        return { quantity: "1", unit: normalized, name: rest }
      end
      return { quantity: nil, unit: nil, name: raw }
    end

    qty = match[1]
    rest = raw[match[0].length..]

    # Check if next word is a known unit
    word = rest.split(/\s+/, 2).first&.downcase
    if UNIT_NORMALIZATION.key?(word)
      normalized = UNIT_NORMALIZATION[word]
      name = rest.split(/\s+/, 2).last || ""
      { quantity: qty, unit: normalized, name: name.strip }
    elsif COUNT_WORDS.include?(word)
      # "4 large eggs" → qty: "4", unit: "whole", name: "large eggs"
      { quantity: qty, unit: "whole", name: rest.strip }
    else
      { quantity: qty, unit: nil, name: rest.strip }
    end
  end

  def parse_instructions(text)
    return [] if text.blank?

    text.lines.filter_map { |line|
      line = line.strip
      match = line.match(/^(\d+)\.\s+(.+)/)
      next unless match

      { step_number: match[1].to_i, instruction: match[2].strip }
    }
  end

  def parse_nutrition(text)
    return {} if text.blank?

    nutrition = {}
    text.lines.each do |line|
      line = line.strip
      next unless line.start_with?("|")
      next if line.include?("---")

      cells = line.split("|").map(&:strip).reject(&:empty?)
      next unless cells.length >= 2

      label = cells[0].downcase.gsub(/\*+/, "").strip
      next if label == "nutrient"
      next if label.include?("net carbs")

      value_str = cells[1].gsub(/\*+/, "").strip
      key = NUTRITION_KEY_MAP[label]
      next unless key

      numeric = value_str.gsub(/[^\d.]/, "")
      next if numeric.empty?

      nutrition[key] = key == :calories ? numeric.to_i : numeric.to_f
    end

    nutrition
  end

  def parse_tips(text)
    return [] if text.blank?

    text.lines.filter_map { |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      tip = line.sub(/^-\s*/, "").strip
      tip.empty? ? nil : tip
    }
  end
end
