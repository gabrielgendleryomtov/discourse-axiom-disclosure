# frozen_string_literal: true

require "json"
require "fileutils"

module ::AxiomDisclosure
  class DisclosureService
    class << self
      # Main entry point: called from controller
      def flag_disclosure(post, actor)
        raise Discourse::InvalidAccess, "staff only" unless actor&.staff?
        raise ArgumentError, "post required" if post.blank?

        user = post.user

        payload = build_payload(post, user, actor)

        hidden = hide_post(post, actor)
        silenced = silence_user(user, actor)

        exported_path = export_payload(payload)

        notified = notify_external(payload)

        {
          post_id: post.id,
          topic_id: post.topic_id,
          user_id: user.id,
          actor_id: actor.id,
          hidden: hidden,
          silenced: silenced,
          export_path: exported_path,
          notified: notified
        }
      end

      # -----------------------------
      # Payload and exporting
      # -----------------------------

      def build_payload(post, user, actor)
        {
          created_at: Time.zone.now.iso8601,
          plugin: "axiom-disclosure",
          actor: {
            id: actor.id,
            username: actor.username,
            name: actor.name
          },
          user: {
            id: user.id,
            username: user.username,
            name: user.name
          },
          post: {
            id: post.id,
            post_number: post.post_number,
            topic_id: post.topic_id,
            topic_title: post.topic&.title,
            raw: post.raw,
            cooked: post.cooked,
            created_at: post.created_at&.iso8601,
            url: post.full_url
          }
          # TODO (vNext): include staff observation text from confirm dialog
        }
      end

      def export_payload(payload)
        export_dir = SiteSetting.axiom_disclosure_export_dir.to_s.strip
        export_dir = Rails.root.join("tmp", "axiom-disclosures").to_s if export_dir.blank?
        FileUtils.mkdir_p(export_dir)

        export_dir = "/var/discourse/shared/disclosures" if export_dir.blank?

        FileUtils.mkdir_p(export_dir)

        ts = Time.zone.now.strftime("%Y%m%d_%H%M%S")
        user_id = payload.dig(:user, :id) || "unknown"
        post_id = payload.dig(:post, :id) || "unknown"

        filename = "disclosure_#{ts}_post_#{post_id}_user_#{user_id}.json"
        path = File.join(export_dir, filename)

        File.write(path, JSON.pretty_generate(payload))

        path
      rescue => e
        Rails.logger.error("[axiom-disclosure] export failed: #{e.class}: #{e.message}")
        raise
      end

      # -----------------------------
      # Post hiding
      # -----------------------------

      def hide_post(post, actor)
        return true if post.hidden?

        reason = SiteSetting.axiom_disclosure_silence_reason.to_s

        # Create a staff flag for audit/review purposes (does not guarantee hiding)
        PostActionCreator.create(
          actor,
          post,
          :inappropriate,
          message: reason,
          reason: reason,
          context: "axiom-disclosure",
          silent: true
        )

        # Explicitly hide the post (guaranteed)
        hide_action_type_id = PostActionType.types[:inappropriate]
        post.hide!(hide_action_type_id, reason)

        post.reload.hidden?
      rescue => e
        Rails.logger.error("[axiom-disclosure] hide_post failed for post #{post.id}: #{e.class}: #{e.message}")
        raise
      end


      # -----------------------------
      # User silencing
      # TODO (vNext): extend silenced_till with new flag
      # -----------------------------

      def silence_user(user, actor)
        hours = SiteSetting.axiom_disclosure_silence_duration_hours.to_i
        return false if hours <= 0

        silenced_till = hours.hours.from_now
        reason = SiteSetting.axiom_disclosure_silence_reason.to_s

        UserSilencer.silence(
          user,
          actor,
          { silenced_till: silenced_till, reason: reason }
        )

        true
      rescue => e
        Rails.logger.error("[axiom-disclosure] silence failed for user #{user.id}: #{e.class}: #{e.message}")
        raise
      end


      # -----------------------------
      # External notification (stub)
      # -----------------------------

      def notify_external(payload)
        # Placeholder for integration (e.g. email, webhook, Slack, etc.)
        # For v0.1.0 we intentionally do nothing and return false.
        false
      end
    end
  end
end
