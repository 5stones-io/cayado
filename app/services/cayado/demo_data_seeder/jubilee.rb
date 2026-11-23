module Cayado
  class DemoDataSeeder
    # Jubilee Christian Center, copied from Lovable's mockup data
    # (cayado-staff-planner/src/lib/cayado-data.ts). Dates aren't here: the
    # seeder works them out for the year it runs in (see DemoDataSeeder).
    #
    # Lovable only wrote Rooted's weeks. The other series' week titles and
    # scriptures, and Advent's big ideas, are ours, so This Week has a
    # Sunday to show all year.
    module Jubilee
      CITY = "Fairfax".freeze
      STATE = "VA".freeze
      TIMEZONE = "America/New_York".freeze
      EMAIL_DOMAIN = "jubilee.example".freeze

      # initials => [first, last, title, role]
      STAFF = {
        "DC" => ["David", "Chen", "Lead Pastor", "owner"],
        "MR" => ["Marcus", "Reyes", "Executive Pastor", "admin"],
        "EP" => ["Elena", "Park", "Worship Pastor", "member"],
        "SW" => ["Sarah", "Whitfield", "Kids Pastor", "member"],
        "JA" => ["Jordan", "Adebayo", "Youth Pastor", "member"],
        "LH" => ["Linnea", "Hoffman", "Small Groups Director", "member"],
      }.freeze

      MINISTRY_LEADS = { "kids" => "SW", "youth" => "JA", "small-groups" => "LH", "worship" => "EP" }.freeze

      VISION = { title: "2026–2030 Vision", start_year: 2026, end_year: 2030 }.freeze

      PILLARS = [
        {
          title: "Reach", tone: "ink", editors: %w[DC MR],
          blurb: "We exist to make Jesus known across Fairfax — through hospitality, presence, and a clear invitation.",
          moves: {
            "reach-reston" => "Plant a second Sunday gathering in Reston by 2027",
            "reach-sundays" => "Quarterly community Sundays designed for guests",
            "reach-onepath" => "Train every member in the One Conversation pathway",
          },
        },
        {
          title: "Disciple", tone: "sage", editors: %w[DC LH SW],
          blurb: "We form ordinary disciples into people who look, love, and live like Jesus across every season of life.",
          moves: {
            "disc-rooted" => "Re-launch small groups around the Rooted curriculum",
            "disc-cohort" => "Year-long discipleship cohorts for emerging leaders",
            "disc-family" => "Family discipleship rhythms aligned to Sunday teaching",
          },
        },
        {
          title: "Send", tone: "terracotta", editors: %w[DC JA],
          blurb: "We send our people into the city, the marketplace, and the nations — equipped, blessed, and supported.",
          moves: {
            "send-miss" => "Commission 5 long-term missionaries by 2030",
            "send-market" => "Launch a marketplace leaders cohort",
            "send-upg" => "Partnership with two unreached people group works",
          },
        },
      ].freeze

      YEARS = {
        2026 => ["Year of Foundations", ["Launch Rooted across all small groups", "Hire a Reston campus pastor",
                                         "Reach 1,000 average weekend attendance"]],
        2027 => ["Year of Multiplication", ["Open Reston Sunday gathering", "First discipleship cohort graduates (24 leaders)",
                                            "Send first missionary family"]],
        2028 => ["Year of Depth", ["Family discipleship curriculum K–12", "Marketplace cohort of 30 leaders"]],
        2029 => ["Year of Influence", ["Citywide gospel partnership", "Second campus self-sustaining"]],
        2030 => ["Year of Sending", ["5 missionaries commissioned", "Third gathering scoped"]],
      }.freeze

      # `starts` names a rule in DemoDataSeeder#series_start.
      # Weeks: [title, scripture, big_idea, {ministry_key => plan}, thread].
      SERIES = {
        "rooted" => {
          title: "Rooted", theme: "A study of Colossians", scripture: "Colossians 1–4", move: "disc-rooted",
          starts: :second_sunday_of_february,
          weeks: [
            ["The Supremacy of Christ", "Colossians 1:15–23",
             "Christ is before all things, and in him all things hold together. Our roots go down into a Person, not a project.",
             { "kids" => "Creation story retold — Jesus was there, Jesus made it, Jesus holds it.",
               "youth" => "Discussion night: where am I trying to hold my own world together?",
               "small-groups" => "Sermon-aligned guide: 'What are you rooted in?'",
               "worship" => "Set list around the supremacy of Christ — 'All Creatures', 'Behold Our God'.", },
             [["SW", "Should the kids memory verse be Col 1:16 or 1:17? I'd lean 1:17 for the holding-together image."],
              ["DC", "1:17 — yes. Let's align."]],],
            ["Rooted and Built Up", "Colossians 2:6–7",
             "We received Christ — now we walk in him. Discipleship is the daily, ordinary work of staying rooted.",
             { "kids" => "Tree craft — what helps our faith grow strong?",
               "small-groups" => "Practices week — pick one rhythm to try together.",
               "worship" => "Quieter, contemplative set. Communion mid-service.", },],
            ["Free in Christ", "Colossians 2:13–15",
             "The record of debt against us — nailed to the cross. We don't strive for what we already have.",
             { "youth" => "Testimony night — students share 'what I was free from'.",
               "worship" => "'O Praise the Name', 'Living Hope'.", },],
            ["Set Your Mind", "Colossians 3:1–4",
             "Our life is hidden with Christ in God. We set our minds on things above — and it changes how we live below.",],
            ["The New Self", "Colossians 3:5–17",
             "Put off, put on. Christian formation is both a death and a clothing — and it happens in community.",
             { "kids" => "'Putting on' object lesson — kindness, patience, gentleness as a costume of Christ.",
               "small-groups" => "Confession + prayer night.", },],
            ["Devoted to Prayer", "Colossians 4:2–6",
             "Rooted people pray. We close the series by re-committing to a praying church.",
             { "small-groups" => "Prayer walk in neighborhoods.",
               "worship" => "Extended prayer + response time, lighter song count.", },],
          ],
        },
        "unshakable" => {
          title: "Unshakable", theme: "Lessons from David", scripture: "1 Samuel 16 – 2 Samuel 7", move: "disc-cohort",
          starts: :two_weeks_after_easter,
          weeks: [
            # No scripture yet: This Week's "needs a scripture anchor".
            ["Chosen", nil],
            ["Giants", "1 Samuel 17:32–50"],
            ["Waiting in the Wilderness", "1 Samuel 24:1–15"],
            ["Strength in the Lord", "1 Samuel 30:1–6"],
            ["Dancing Before the Lord", "2 Samuel 6:12–22"],
            ["A House Forever", "2 Samuel 7:8–17"],
          ],
        },
        "home" => {
          title: "Home", theme: "What family was meant to be", scripture: "Selected texts", move: "disc-family",
          starts: :fourth_sunday_of_august,
          weeks: [
            ["In the Beginning", "Genesis 2:18–25"],
            ["One Flesh", "Ephesians 5:21–33"],
            ["Honor", "Ephesians 6:1–4"],
            ["Teach Them Diligently", "Deuteronomy 6:4–9"],
            ["The Household of God", "Ephesians 2:19–22"],
          ],
        },
        "light" => {
          title: "Light of the World", theme: "An Advent journey", scripture: "John 1; Isaiah 9; Luke 1–2", move: "send-market",
          starts: :advent_sunday,
          weeks: [
            ["The Light Promised", "Isaiah 9:2–7", "The people walking in darkness have seen a great light — God keeps his promises in the dark."],
            ["The Light Announced", "Luke 1:26–38", "Nothing is impossible with God. Mary's yes is the shape of every disciple's yes."],
            ["The Light Born", "Luke 2:1–20", "The Light comes small, to a manger, for shepherds — good news for ordinary people."],
            ["The Light Has Come", "John 1:1–14", "The Word became flesh and moved into the neighborhood. We carry his light into ours."],
          ],
        },
      }.freeze

      # `on` names a rule in DemoDataSeeder#event_date; weeks = how long it runs.
      ROADMAP = [
        { title: "Vision Sunday", lane: "major_event", on: :second_sunday_of_january, weeks: 1, color: "terracotta", owner: "DC",
          notes: "Cast the 2026–2030 vision. All-staff prayer the night before.", },
        { title: "Easter Sunday", lane: "major_event", on: :easter, weeks: 1, color: "gold", owner: "EP",
          notes: "Two services, brass ensemble, baptisms after second service.", move: "reach-sundays", },
        { title: "Summer Nights Outreach", lane: "outreach", on: :second_sunday_of_june, weeks: 7, color: "sage", owner: "MR",
          pillar: "Reach", },
        { title: "Kids & Youth Camps", lane: "ministry_initiative", on: :second_sunday_of_july, weeks: 2, color: "sky", owner: "SW" },
        { title: "Fall Kickoff Sunday", lane: "major_event", on: :second_sunday_of_september, weeks: 1, color: "terracotta",
          owner: "MR", move: "reach-sundays", },
        { title: "Small Groups Launch", lane: "ministry_initiative", on: :third_sunday_of_september, weeks: 3, color: "sky",
          owner: "LH", move: "disc-rooted", },
        { title: "Gratitude Weekend", lane: "major_event", on: :third_sunday_of_november, weeks: 1, color: "gold", owner: "DC" },
        { title: "Christmas Eve Services", lane: "major_event", on: :christmas_eve, weeks: 1, color: "gold", owner: "EP" },
      ].freeze

      # attached to (series key or roadmap title) => [title, url, owner, hours ago, tags]
      ATTACHMENTS = {
        "rooted" => [
          ["Rooted — full series outline", "https://docs.google.com/document/d/1abc/edit", "DC", 48, %w[outline teaching]],
          ["Week-by-week scripture brief", "https://docs.google.com/document/d/2def/edit", "DC", 120, %w[exegesis]],
          ["Small groups discussion guide", "https://docs.google.com/document/d/3ghi/edit", "LH", 24, %w[small-groups discussion]],
          ["Worship set — Rooted (running)", "https://docs.google.com/spreadsheets/d/4jkl/edit", "EP", 3, %w[worship setlist]],
          ["Visual identity & slide kit", "https://docs.google.com/presentation/d/5mno/edit", "MR", 168, %w[design]],
        ],
        "Easter Sunday" => [
          ["Easter run-of-show", "https://docs.google.com/document/d/6pqr/edit", "MR", 24, %w[production]],
          ["Baptism candidate list", "https://docs.google.com/spreadsheets/d/7stu/edit", "SW", 1, %w[pastoral]],
        ],
        "Summer Nights Outreach" => [
          ["Summer Nights — neighborhood plan", "https://docs.google.com/document/d/8vwx/edit", "MR", 168, %w[outreach]],
        ],
        "unshakable" => [
          ["1 & 2 Samuel reading plan", "https://docs.google.com/document/d/9yzab/edit", "DC", 96, %w[reading]],
        ],
      }.freeze

      TOPIC_WEIGHTS = {
        "rooted" => { "Identity in Christ" => 3, "Discipleship" => 3, "Prayer" => 2, "The Gospel" => 2, "Holy Spirit" => 1 },
        "unshakable" => { "Suffering & Hope" => 3, "Identity in Christ" => 2, "Prayer" => 2, "Worship" => 1 },
        "home" => { "Family & Marriage" => 3, "Community" => 2, "Discipleship" => 1 },
        "light" => { "The Gospel" => 3, "Worship" => 2, "Mission & Evangelism" => 2, "Suffering & Hope" => 1 },
      }.freeze

      # Giving by calendar month, in dollars, and the monthly budget.
      MONTHLY_GIVING = [98_000, 102_000, 121_000, 145_000, 110_000, 118_000,
                        126_000, 119_000, 132_000, 128_000, 141_000, 172_000,].freeze
      MONTHLY_BUDGET = 117_000

      # One weekend's split (Planning Center's groupings, not Cayado ministries).
      # In-person rows scale with that Sunday's attendance; Online doesn't.
      IN_PERSON = { "Adults" => 612, "Youth" => 94, "Kids" => 168 }.freeze
      ONLINE = 220

      # Sundays Lovable's attendance chart calls out.
      SPIKES = { "Easter" => [:easter, 1180, 46], "Vision Sunday" => [:second_sunday_of_january, 1040, 18] }.freeze

      SNAPSHOT = {
        households: 412,
        life_stages: [
          { "label" => "Young families with kids", "pct" => 32 },
          { "label" => "Empty-nesters", "pct" => 22 },
          { "label" => "Singles & young adults", "pct" => 18 },
          { "label" => "Seniors", "pct" => 14 },
          { "label" => "Couples, no kids at home", "pct" => 14 },
        ],
        season_markers: [
          { "label" => "funerals", "count" => 3 },
          { "label" => "births", "count" => 7 },
          { "label" => "baptisms scheduled", "count" => 2 },
          { "label" => "new households", "count" => 12 },
          { "label" => "leadership transitions", "count" => 4 },
        ],
        note: "A season of new life and of loss. Lead with hope.",
      }.freeze
    end
  end
end
