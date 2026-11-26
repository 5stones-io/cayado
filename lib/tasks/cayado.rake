namespace :cayado do
  desc "Seed Lovable's demo church (Jubilee Christian Center). SLUG=jubilee OWNER_EMAIL=you@example.com"
  task demo: :environment do
    church = Cayado::DemoDataSeeder.seed_church!(slug: ENV.fetch("SLUG", "jubilee"), owner_email: ENV["OWNER_EMAIL"])
    puts "Seeded #{church.brand_name} (#{church.slug}): #{church.memberships.count} staff, " \
         "#{church.sermon_series.count} series, #{church.weekly_metrics.count} Sundays of numbers."
    puts "Owner: #{ENV['OWNER_EMAIL']} (sign in with an emailed code, then set up two-step)." if ENV["OWNER_EMAIL"].present?
  rescue Cayado::DemoDataSeeder::AlreadySeeded => e
    abort "#{e.message}. Nothing changed."
  end
end
