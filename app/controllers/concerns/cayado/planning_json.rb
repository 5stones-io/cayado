module Cayado
  # The JSON shapes the planning endpoints share, so a person or a slot
  # looks the same wherever it appears (web SPA and cayado_mobile).
  module PlanningJson
    private

    # A teammate as shown next to their work: Avatar initials + name + title.
    def person_json(membership)
      return nil if membership.nil?

      account = membership.account
      name = account.name || account.email
      {
        membership_id: membership.id,
        name: name,
        title: membership.title,
        initials: name.split(/[\s@.]+/).first(2).map { _1[0] }.join.upcase,
      }
    end

    # The AdvancesBadge: a pillar and, usually, one of its moves.
    def advances_json(move, pillar: move&.pillar)
      return nil if pillar.nil?

      { pillar: { id: pillar.id, title: pillar.title, tone: pillar.tone }, move: move && { id: move.id, text: move.text } }
    end

    def series_json(series)
      {
        id: series.id,
        title: series.title,
        theme: series.theme,
        scripture: series.scripture,
        starts_on: series.starts_on,
        ends_on: series.ends_on,
        owner: person_json(series.owner_membership),
        advances: advances_json(series.move),
        weeks_count: series.weeks.size,
        alignment: series.alignment,
      }
    end

    # One alignment slot: the ministry, its lead, the plan or nil
    # (awaiting), and whether the signed-in person may write it.
    def slot_json(ministry, plan)
      {
        ministry: { key: ministry.key, name: ministry.name, color: ministry.color },
        lead: person_json(ministry.lead_membership),
        can_edit: ministry.plannable_by?(Current.membership),
        plan: plan && {
          body: plan.body,
          memory_verse: plan.memory_verse,
          updated_by: person_json(plan.updated_by_membership),
          updated_at: plan.updated_at,
        },
      }
    end

    def week_json(week, ministries:)
      plans = week.alignment_plans.index_by(&:ministry_id)
      {
        id: week.id,
        position: week.position,
        preached_on: week.preached_on,
        title: week.title,
        scripture: week.scripture,
        big_idea: week.big_idea,
        slots: ministries.map { slot_json(_1, plans[_1.id]) },
        comments_count: week.comments.size,
        congregation_snapshot_id: week.congregation_snapshot_id,
      }
    end

    def comment_json(comment)
      {
        id: comment.id,
        body: comment.body,
        author: person_json(comment.membership),
        mine: comment.membership_id.present? && comment.membership_id == Current.membership.id,
        created_at: comment.created_at,
      }
    end

    def vision_json(vision)
      {
        id: vision.id,
        title: vision.title,
        subtitle: vision.subtitle,
        start_year: vision.start_year,
        end_year: vision.end_year,
        pillars: vision.pillars.map { pillar_json(_1) },
        years: vision.horizon_years.map { year_json(_1) },
      }
    end

    def pillar_json(pillar)
      {
        id: pillar.id,
        title: pillar.title,
        blurb: pillar.blurb,
        tone: pillar.tone,
        can_edit: pillar.editable_by?(Current.membership),
        editors: pillar.pillar_editors.map { person_json(_1.membership) },
        moves: pillar.moves.map { move_json(_1) },
      }
    end

    # A move and the series that advance it (LinkChips on the Vision screen).
    def move_json(move)
      { id: move.id, text: move.text,
        sermon_series: move.sermon_series.sort_by(&:id).map { { id: _1.id, title: _1.title } } }
    end

    def year_json(year)
      { year: year.year, headline: year.headline, goals: year.goals }
    end

    def ministry_json(ministry)
      { key: ministry.key, name: ministry.name, color: ministry.color, position: ministry.position,
        lead: person_json(ministry.lead_membership) }
    end

    # One bar on the Roadmap. Series and items share the shape; `kind` says
    # which endpoint edits it (sermon_series vs roadmap_items).
    def roadmap_series_json(series)
      {
        kind: "sermon_series", id: series.id, lane: "sermon_series", title: series.title,
        starts_on: series.starts_on, ends_on: series.ends_on, color: "ink", notes: series.theme,
        owner: person_json(series.owner_membership), advances: advances_json(series.move),
        attachments_count: series.attachments.size, can_edit: admin?,
        weeks: series.weeks.map { { id: _1.id, position: _1.position, preached_on: _1.preached_on, title: _1.title } },
      }
    end

    def roadmap_item_json(item)
      {
        kind: "roadmap_item", id: item.id, lane: item.lane, title: item.title,
        starts_on: item.starts_on, ends_on: item.ends_on, color: item.color, notes: item.notes,
        owner: person_json(item.owner_membership), advances: advances_json(item.move, pillar: item.pillar),
        attachments_count: item.attachments.size, can_edit: admin?,
      }
    end

    def attachment_json(attachment)
      {
        id: attachment.id, title: attachment.title, url: attachment.url, kind: attachment.kind,
        owner: person_json(attachment.owner_membership), tags: attachment.tags,
        can_edit: attachment.editable_by?(Current.membership), updated_at: attachment.updated_at,
      }
    end

    def series_weights_json(series)
      series.series_topics.sort_by { [_1.topic.position, _1.topic_id] }
            .map { { topic_id: _1.topic_id, name: _1.topic.name, weight: _1.weight } }
    end

    def ministries
      @ministries ||= Current.church.ministries.includes(lead_membership: :account).to_a
    end
  end
end
