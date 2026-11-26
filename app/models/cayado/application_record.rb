module Cayado
  # Planning-domain models. isolate_namespace makes their tables cayado_*.
  class ApplicationRecord < ::ApplicationRecord
    self.abstract_class = true

    private

    # For a reference that must stay inside one church: a series' move, a
    # ministry's lead. Adds an error rather than raising, so the API
    # answers 422 naming the field.
    def must_belong_to_church(attribute, record, church)
      return if record.nil? || church.nil?
      return if record_church(record) == church

      errors.add(attribute, "isn't part of this church")
    end

    def record_church(record)
      case record
      when ::Membership then record.church
      when Cayado::Move then record.pillar&.vision&.church
      when Cayado::Ministry then record.church
      end
    end
  end
end
