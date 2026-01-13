# frozen_string_literal: true

module ::AxiomDisclosure
  class DisclosureController < ::ApplicationController
    before_action :ensure_logged_in
    before_action :ensure_staff
    before_action :ensure_plugin_enabled

    def flag
      Rails.logger.warn("[axiom-disclosure] flag hit; post_id=#{params[:post_id]} user=#{current_user&.username}")

      post_id = params.require(:post_id).to_i
      observation = params[:observation].to_s
      
      Rails.logger.warn("[axiom-disclosure] Controller observation is #{observation}")

      post = Post.find_by(id: post_id)
      raise Discourse::NotFound unless post

      result = AxiomDisclosure::DisclosureService.flag_disclosure(post, current_user, observation: observation)

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
  end
end