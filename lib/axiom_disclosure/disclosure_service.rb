# frozen_string_literal: true

require "json"
require "fileutils"

module ::AxiomDisclosure
  class DisclosureService
    class << self
      # Main entry point: called from controller
      def flag_disclosure(record, actor, observation: "")
        raise Discourse::InvalidAccess, "staff only" unless actor&.staff?
        raise ArgumentError, "record required" if record.blank?

        observation = observation.to_s.strip
        observation = observation[0, 10_000]

        if record.is_a?(Post)
          payload = build_post_payload(record, record.user, actor, observation: observation)
          hidden = hide_post(record)
          silenced = silence_user(record.user, actor)
          result_ids = { post_id: record.id, topic_id: record.topic_id, user_id: record.user.id }
        elsif defined?(::Chat::Message) && record.is_a?(::Chat::Message)
          payload = build_chat_payload(record, record.user, actor, observation: observation)
          hidden = hide_chat_message(record, actor)
          silenced = silence_user(record.user, actor)
          result_ids = {
            chat_message_id: record.id,
            chat_channel_id: record.chat_channel_id,
            user_id: record.user.id,
          }
        else
          raise ArgumentError, "unsupported record type: #{record.class}"
        end

        exported_path = export_payload(payload)

        notified = notify_external(payload)

        result_ids.merge(
          actor_id: actor.id,
          hidden: hidden,
          silenced: silenced,
          export_path: exported_path,
          notified: notified,
        )
      end

      # -----------------------------
      # Payload and exporting
      # -----------------------------

      def build_post_payload(post, user, actor, observation: "")
        {
          created_at: Time.zone.now.iso8601,
          plugin: "axiom-disclosure",
          observation: observation,
          actor: {
            id: actor.id,
            username: actor.username,
            name: actor.name,
          },
          user: {
            id: user.id,
            username: user.username,
            name: user.name,
          },
          post: {
            id: post.id,
            post_number: post.post_number,
            topic_id: post.topic_id,
            topic_title: post.topic&.title,
            raw: post.raw,
            cooked: post.cooked,
            created_at: post.created_at&.iso8601,
            url: post.full_url,
          },
        }
      end

      def build_chat_payload(chat_message, user, actor, observation: "")
        {
          created_at: Time.zone.now.iso8601,
          plugin: "axiom-disclosure",
          observation: observation,
          actor: {
            id: actor.id,
            username: actor.username,
            name: actor.name,
          },
          user: {
            id: user.id,
            username: user.username,
            name: user.name,
          },
          chat_message: {
            id: chat_message.id,
            channel_id: chat_message.chat_channel_id,
            thread_id: chat_message.thread_id,
            message: chat_message.message,
            cooked: chat_message.cooked,
            created_at: chat_message.created_at&.iso8601,
          },
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
        if payload[:post]
          record_ref = "post_#{payload.dig(:post, :id) || "unknown"}"
        elsif payload[:chat_message]
          record_ref = "chat_message_#{payload.dig(:chat_message, :id) || "unknown"}"
        else
          record_ref = "record_unknown"
        end

        filename = "disclosure_#{ts}_#{record_ref}_user_#{user_id}.json"
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

      def hide_post(post)
        Rails.logger.warn(
          "[axiom-disclosure] hide_post start post_id=#{post.id} hidden?=#{post.hidden?}",
        )
        return false if post.hidden?

        if SiteSetting.axiom_disclosure_notify_user
          hide_action_type_id = PostActionType.types[:inappropriate]
          post.hide!(hide_action_type_id)
        else
          hide_post_without_user_notification(post)
        end

        post.reload.hidden?
      rescue => e
        Rails.logger.error(
          "[axiom-disclosure] hide_post failed for post #{post.id}: #{e.class}: #{e.message}",
        )
        raise
      end

      def hide_post_without_user_notification(post)
        should_reset_bumped_at = post.is_last_reply? && !post.whisper?

        Post.transaction do
          post.skip_validation = true
          should_update_user_stat = true

          reason_id =
            if post.hidden_at
              Post.hidden_reasons[:flag_threshold_reached_again]
            else
              Post.hidden_reasons[:flag_threshold_reached]
            end

          post.update!(hidden: true, hidden_at: Time.zone.now, hidden_reason_id: reason_id)

          any_visible_posts_in_topic =
            Post.exists?(topic_id: post.topic_id, hidden: false, post_type: Post.types[:regular])

          if post.is_first_post? || !any_visible_posts_in_topic
            post.topic.update_status(
              "visible",
              false,
              Discourse.system_user,
              { visibility_reason_id: Topic.visibility_reasons[:op_flag_threshold_reached] },
            )
            should_update_user_stat = false
          end

          # Keep user stats and topic counts aligned with core hide! behavior.
          UserStatCountUpdater.decrement!(post) if should_update_user_stat
        end

        post.topic.reset_bumped_at if should_reset_bumped_at
      end

      def hide_chat_message(chat_message, actor)
        return false if chat_message.deleted_at.present?

        ::Chat::TrashMessage.call(
          params: {
            message_id: chat_message.id,
            channel_id: chat_message.chat_channel_id,
          },
          guardian: actor.guardian,
        ) do
          on_success { return true }
          on_failure { raise Discourse::InvalidAccess }
          on_model_not_found(:message) { raise Discourse::NotFound }
          on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
          on_failed_contract do |contract|
            raise ArgumentError, contract.errors.full_messages.join(", ")
          end
        end

        false
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

        actor = User.find(actor.id)

        UserSilencer.silence(user, actor, { silenced_till: silenced_till, reason: reason })

        true
      rescue => e
        Rails.logger.error(
          "[axiom-disclosure] silence failed for user #{user.id}: #{e.class}: #{e.message}",
        )
        raise
      end

      # -----------------------------
      # External notification (stub)
      # -----------------------------

      def notify_external(payload)
        recipient = SiteSetting.axiom_disclosure_notification_email.to_s.strip
        return false if recipient.blank?

        record_ref =
          if payload[:post]
            "post #{payload.dig(:post, :id) || "unknown"}"
          elsif payload[:chat_message]
            "chat message #{payload.dig(:chat_message, :id) || "unknown"}"
          else
            "record unknown"
          end
        user_id = payload.dig(:user, :id) || "unknown"

        subject = "Axiom disclosure report (#{record_ref}, user #{user_id})"
        body = JSON.pretty_generate(payload)

        message =
          ActionMailer::Base.mail(
            to: recipient,
            from: SiteSetting.notification_email,
            subject: subject,
            content_type: "text/plain; charset=UTF-8",
            body: body,
          )

        if defined?(::Email::Sender)
          ::Email::Sender.new(message, :axiom_disclosure_notification).send
        else
          # Fallback for non-Discourse contexts/tests.
          message.deliver_now
        end

        true
      rescue => e
        Rails.logger.error("[axiom-disclosure] notification failed: #{e.class}: #{e.message}")
        false
      end
    end
  end
end
