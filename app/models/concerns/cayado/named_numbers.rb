module Cayado
  # jsonb columns that hold a list of labelled numbers, e.g. by_ministry
  # [{name: "Adults", value: 612}] or life_stages [{label: "Seniors", pct: 14}].
  module NamedNumbers
    extend ActiveSupport::Concern

    class_methods do
      # Each row needs a non-blank `name_key` and a whole number in `range`.
      def validates_named_numbers(attribute, name_key:, number_key:, range: 0..)
        validate do
          rows = public_send(attribute)
          ok = rows.is_a?(Array) && rows.all? do |row|
            row.is_a?(Hash) && row[name_key].to_s.strip.present? &&
              row[number_key].is_a?(Integer) && range.cover?(row[number_key])
          end
          errors.add(attribute, "must be a list of #{name_key} and #{number_key} (#{range})") unless ok
        end
      end
    end
  end
end
