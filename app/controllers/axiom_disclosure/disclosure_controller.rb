# frozen_string_literal: true

module ::AxiomDisclosure
  class DisclosureController < ::ApplicationController
    before_action :ensure_logged_in
    before_action :ensure_staff
    before_action :ensure_plugin_enabled

    def flag
      Rails.logger.warn("[axiom-disclosure] HIT flag: post_id=#{params[:post_id]} actor=#{current_user&.id}")
      
      post_id = params.require(:post_id).to_i
      post = Post.find(post_id)

      result = AxiomDisclosure::DisclosureService.flag_disclosure(post, current_user)

      render_json_dump(result.merge(ok: true))
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


    #   Rails.logger.warn("[axiom-disclosure] flag hit; post_id=#{params[:post_id]} user=#{current_user&.username}")
      
    #   raise Discourse::NotFound unless post

    # rescue => e
    #   Rails.logger.error("[axiom-disclosure] error in /flag: #{e.class}: #{e.message}")
    #   raise
