# frozen_string_literal: true

AxiomDisclosure::Engine.routes.draw do
  post "/flag" => "disclosure#flag"
end

Discourse::Application.routes.append do
  unless Discourse::Application.routes.named_routes.key?("axiom_disclosure")
    mount ::AxiomDisclosure::Engine, at: "/axiom-disclosure"
  end
end
