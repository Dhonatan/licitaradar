class SavedSearchesController < ApplicationController
  before_action :set_saved_search, only: %i[ edit update destroy ]

  def index
    @saved_searches = Current.user.saved_searches.by_name
  end

  # Pre-filled from the results page ("Salvar esta busca" sends the search params).
  def new
    @saved_search = SavedSearch.from_search_params(search_params, user: Current.user)
    @saved_search.name = @saved_search.suggested_name
  end

  def create
    @saved_search = Current.user.saved_searches.new(saved_search_params)

    if @saved_search.save
      redirect_to saved_searches_path, notice: "Busca “#{@saved_search.name}” salva."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @saved_search.update(saved_search_params)
      redirect_to saved_searches_path, notice: "Busca “#{@saved_search.name}” atualizada."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @saved_search.destroy
    redirect_to saved_searches_path, notice: "Busca “#{@saved_search.name}” excluída.", status: :see_other
  end

  private
    def set_saved_search
      @saved_search = Current.user.saved_searches.find(params[:id])
    end

    def search_params
      params.permit(:q, :niche, :min_value, :max_value, :closing_within, :states, :modality_ids, states: [], modality_ids: [])
    end

    def saved_search_params
      params.expect(saved_search: [ :name, :query, :niche_slug, :min_value, :max_value, :closing_within, :active, :notify_daily,
                                    states: [], modality_ids: [] ])
    end
end
