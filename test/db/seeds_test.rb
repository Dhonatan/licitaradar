require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  def load_seeds
    load Rails.root.join("db/seeds.rb")
  end

  def objects_for(**params)
    Tenders::Search.new(params.merge(page: 1), per_page: 100).results.map(&:object_description)
  end

  test "creates 30 valid fictional tenders, 28 open, and is idempotent" do
    load_seeds
    load_seeds

    assert_equal 30, Tender.count
    assert_equal 28, Tender.open_for_proposals.count
    assert Tender.all.all?(&:valid?)
    assert Tender.where(estimated_value: 0).exists?, "some confidential values"
  end

  test "every default niche finds its demo tenders and skips the others" do
    load_seeds

    marketing = objects_for(niche: "marketing-comunicacao")
    eventos = objects_for(niche: "eventos")
    ti = objects_for(niche: "tecnologia-informacao")

    assert_equal 8, marketing.size, marketing.inspect
    assert_equal 8, eventos.size, eventos.inspect
    assert_equal 8, ti.size, ti.inspect
    assert_includes marketing, "Campanha publicitária de prevenção à dengue"
    assert_includes eventos, "Serviço de buffet e coffee break para eventos da instituição"
    assert_includes ti, "Aquisição de computadores e notebooks para as escolas municipais"
    assert_not_includes ti, "Manutenção do sistema de abastecimento de água"
    assert_not_includes marketing, "Pavimentação asfáltica de vias urbanas"
  end
end
