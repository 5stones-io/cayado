# Sign-in emails: the 6-digit "set your password" code (plus a link that
# fills it in on the web), and the notice that an admin reset someone's
# two-step sign-in. Resend in production, the log everywhere else.
module AuthEmail
  TEMPLATES = Cayado::Engine.root.join("app/views/auth_mailer")

  def self.password_code(email:, code:, link:)
    Rails.logger.warn("\n\n🔐 [cayado] Password code for #{email}: #{code}\n#{link}\n\n")
    return unless Rails.env.production?

    deliver(to: email, subject: "Your Cayado code: #{code}", template: "password_code",
            locals: { code: code, link: link })
  end

  def self.two_step_reset(email:, church_name:, by_name:)
    Rails.logger.warn("\n\n🔐 [cayado] Two-step sign-in reset for #{email} by #{by_name} (#{church_name})\n\n")
    return unless Rails.env.production?

    deliver(to: email, subject: "Your two-step sign-in was reset", template: "two_step_reset",
            locals: { church_name: church_name, by_name: by_name })
  end

  def self.deliver(to:, subject:, template:, locals:)
    resp = Resend::Emails.send({
      from:    ENV["MAILER_FROM"].presence || "noreply@cayado.io",
      to:      [to],
      subject: subject,
      html:    render("#{template}.html.erb", locals),
      text:    render("#{template}.text.erb", locals)
    })
    Rails.logger.warn("[resend] #{template} send result: #{resp.inspect}")
  end
  private_class_method :deliver

  def self.render(file, locals)
    ERB.new(File.read(TEMPLATES.join(file))).result_with_hash(locals)
  end
  private_class_method :render
end
