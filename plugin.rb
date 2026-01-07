# frozen_string_literal: true

# name: axiom-disclosure
# about: Staff-only disclosure flagging for safeguarding
# version: 0.1.0
# authors: Axiom Maths / Gabriel Gendler Yom-Tov
# url: https://axiommaths.com

enabled_site_setting :axiom_disclosure_enabled

require_relative "lib/axiom_disclosure/engine"
require_relative "lib/axiom_disclosure/disclosure_service"

load File.expand_path("../config/routes.rb", __FILE__)

after_initialize do
  Rails.logger.warn("[axiom-disclosure] plugin after_initialize ran")
end
