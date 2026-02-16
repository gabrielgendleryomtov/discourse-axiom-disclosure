# frozen_string_literal: true

module ::AxiomDisclosure
  class DisclosureController < ::ApplicationController
    requires_plugin "axiom-disclosure"

    before_action :ensure_logged_in
    before_action :ensure_staff
    before_action :ensure_plugin_enabled

    def flag
      Rails.logger.warn(
        "[axiom-disclosure] flag hit; post_id=#{params[:post_id]} chat_message_id=#{params[:chat_message_id]} user=#{current_user&.username}",
      )

      observation = params[:observation].to_s

      result =
        if params[:chat_message_id].present?
          chat_message = find_chat_message(params[:chat_message_id].to_i)
          AxiomDisclosure::DisclosureService.flag_disclosure(
            chat_message,
            current_user,
            observation: observation,
          )
        else
          post = Post.find_by(id: params.require(:post_id).to_i)
          raise Discourse::NotFound unless post
          AxiomDisclosure::DisclosureService.flag_disclosure(
            post,
            current_user,
            observation: observation,
          )
        end

      render_json_dump(result.merge(ok: true))
    rescue => e
      Rails.logger.error("[axiom-disclosure] error in /flag: #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
      raise
    end

    private

    def ensure_staff
      raise Discourse::InvalidAccess unless current_user&.staff?
    end

    def ensure_plugin_enabled
      raise Discourse::InvalidAccess unless SiteSetting.axiom_disclosure_enabled
    end

    def find_chat_message(chat_message_id)
      raise Discourse::NotFound if !defined?(::Chat::Message)

      chat_message = ::Chat::Message.find_by(id: chat_message_id)
      raise Discourse::NotFound unless chat_message

      guardian = Guardian.new(current_user)
      unless guardian.can_join_chat_channel?(chat_message.chat_channel)
        raise Discourse::InvalidAccess
      end

      chat_message
    end
  end
end
