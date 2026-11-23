# Emails from one teammate to others: Notify team's heads-up about a sermon
# series. Resend in production, the log everywhere else (like AuthEmail).
module TeamEmail
  TEMPLATES = Cayado::Engine.root.join("app/views/team_mailer")

  def self.heads_up(to:, church_name:, subject:, body:, link:)
    Rails.logger.warn("\n\n📣 [cayado] Heads-up to #{to} (#{church_name}): #{subject}\n#{link}\n\n")
    return unless Rails.env.production?

    locals = { church_name: church_name, subject: subject, body: body, link: link }
    resp = Resend::Emails.send({
      from:    ENV["MAILER_FROM"].presence || "noreply@cayado.io",
      to:      [to],
      subject: subject,
      html:    render("heads_up.html.erb", locals),
      text:    render("heads_up.text.erb", locals)
    })
    Rails.logger.warn("[resend] heads_up send result: #{resp.inspect}")
  end

  def self.render(file, locals)
    ERB.new(File.read(TEMPLATES.join(file))).result_with_hash(locals)
  end
  private_class_method :render
end
