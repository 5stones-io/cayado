module Cayado
  # Screens that show one calendar year (Roadmap, Topics): ?year=, else the
  # church's own current year.
  module YearParam
    private

    def year
      @year ||= params[:year].presence&.to_i || Current.church.today.year
    end
  end
end
