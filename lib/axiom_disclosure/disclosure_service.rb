# frozen_string_literal: true

# require "fileutils"
# require "json"

# module ::AxiomDisclosure
#   class DisclosureService
#     EXPORT_DIR_DEFAULT = "/shared/private/axiom-disclosures"

#     def self.flag_disclosure(actor:, post:)
#       raise Discourse::InvalidAccess unless actor&.staff?
#       raise ArgumentError, "post required" if post.blank?

#       user = post.user
#       raise ArgumentError, "post has no user" if user.blank?

#       payload = build_payload(actor: actor, post: post, user: user)

#       export_payload(payload)

#       hide_post(post)
#       silenced = silence_user(user, actor)
#       notified = notify_external(payload)

#       {
#         ok: true,
#         post_id: post.id,
#         user_id: user.id,
#         silenced: silenced,
#         hidden: true,
#         exported: true,
#         notified: notified
#       }
#     end

#     def self.build_payload(actor:, post:, user:)
#       {
#         event: "axiom_disclosure_flagged",
#         timestamp_utc: Time.now.utc.iso8601,
#         actor: {
#           id: actor.id,
#           username: actor.username
#         },
#         user: {
#           id: user.id,
#           username: user.username,
#           email: user.email # optional; remove if you don’t want stored here
#         },
#         post: {
#           id: post.id,
#           topic_id: post.topic_id,
#           post_number: post.post_number,
#           url: post.full_url,
#           raw: post.raw
#         },
#         topic: {
#           id: post.topic.id,
#           title: post.topic.title,
#           url: post.topic.full_url
#         },
#         category: {
#           id: post.topic.category_id,
#           name: post.topic.category&.name
#         }
#       }
#     end

#     def self.export_payload(payload)
#       dir = export_dir
#       FileUtils.mkdir_p(dir)

#       ts = Time.now.utc.strftime("%Y-%m-%dT%H-%M-%SZ")
#       post_id = payload.dig(:post, :id) || "unknown"
#       staff_id = payload.dig(:actor, :id) || "unknown"
      
#       file = File.join(dir, "disclosure_#{ts}_post_#{post_id}_staff_#{staff_id}.json")

#       File.open(file, "w") do |f|
#         f.write(JSON.pretty_generate(payload))
#         f.write("\n")
#       end

#       Rails.logger.warn("[axiom-disclosure] exported disclosure to #{file}")
#     end

#     def self.hide_post(post)
#       return if post.hidden?
#       post.update!(hidden: true)
#       Rails.logger.warn("[axiom-disclosure] hid post #{post.id}")
#     end

#     def self.silence_user(user, actor)
#       hours = SiteSetting.axiom_disclosure_silence_duration_hours.to_i
#       if hours <= 0
#         Rails.logger.warn("[axiom-disclosure] silencing disabled by setting; user not silenced")
#         return false
#       end

#       silenced_till = Time.zone.now + hours.hours

#       # UserSilencer is core Discourse. Method names can vary slightly by version.
#       # We implement with a conservative approach and fall back to direct update if needed.
#       begin
#         silencer = UserSilencer.new(user, actor)
#         silencer.silence(
#           reason: "Axiom safeguarding action",
#           silenced_till: silenced_till
#         )
#       rescue NoMethodError
#         # Fallback approach: set silenced_till directly (less ideal but works)
#         user.update!(silenced_till: silenced_till)
#       end

#       Rails.logger.warn("[axiom-disclosure] silenced user #{user.username} until #{silenced_till}")
#     end

#     def self.notify_external(payload)
#       # Stub for v0.1.0 — implement webhook/email/etc. later
#       Rails.logger.warn("[axiom-disclosure] TODO notify_external called with payload post_id=#{payload.dig(:post, :id)} user=#{payload.dig(:user, :username)}")
#       false
#     end

#     def self.export_dir
#       raw = SiteSetting.axiom_disclosure_export_path.to_s.strip
#       raw.present? ? raw : EXPORT_DIR_DEFAULT
#     end
#   end
# end

# frozen_string_literal: true

module ::AxiomDisclosure
  class DisclosureService
    def self.flag_disclosure(post, actor)
      {
        post_id: post.id,
        actor_id: actor.id,
        silenced: false,
        hidden: false,
        exported: false,
        notified: false
      }
    end
  end
end
