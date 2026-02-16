# frozen_string_literal: true

# name: axiom-disclosure
# about: Staff-only disclosure flagging for safeguarding
# version: 0.1.0
# authors: Axiom Maths / Gabriel Gendler Yom-Tov
# url: https://axiommaths.com

enabled_site_setting :axiom_disclosure_enabled

require_relative "lib/axiom_disclosure/engine"
require_relative "lib/axiom_disclosure/disclosure_service"
require_relative "config/routes"

after_initialize do
  Rails.logger.warn("[axiom-disclosure] plugin.rb after_initialize start")

  next unless SiteSetting.axiom_disclosure_enabled

  Rails.logger.warn("[axiom-disclosure] plugin.rb enabled, preparing export directory")

  dir = SiteSetting.axiom_disclosure_export_dir.to_s.strip
  if dir.present?
    begin
      FileUtils.mkdir_p(dir)
      Rails.logger.warn("[axiom-disclosure] ensured export dir exists: #{dir}")
    rescue => e
      Rails.logger.error(
        "[axiom-disclosure] could not create export dir #{dir}: #{e.class}: #{e.message}",
      )
    end
  end

  Rails.logger.warn("[axiom-disclosure] plugin.rb after_initialize end")
end
