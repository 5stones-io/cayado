# Local development: Lovable's demo church at jubilee.localhost.
# OWNER_EMAIL=you@example.com bin/rails db:seed makes you its owner.
church = Cayado::DemoDataSeeder.seed_church!(owner_email: ENV["OWNER_EMAIL"])
puts "Seeded #{church.brand_name} (#{church.slug})"
