class PagesController < ApplicationController
  def home
    @modalities = Pncp::Modalities::COMPETITIVE.map { |id| [ id, Pncp::Modalities.name_for(id) ] }
  end
end
