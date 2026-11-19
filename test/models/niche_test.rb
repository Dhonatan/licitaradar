require "test_helper"

class NicheTest < ActiveSupport::TestCase
  def load_yaml(yaml)
    file = Tempfile.new([ "niches", ".yml" ])
    file.write(yaml)
    file.close
    Niche.load(file.path)
  ensure
    file&.unlink
  end

  test "ships the default presets" do
    assert_equal %w[ marketing-comunicacao eventos tecnologia-informacao ], Niche.all.map(&:slug)
    assert Niche.all.all? { |niche| niche.name.present? && niche.include_keywords.any? }
    assert_equal "Eventos", Niche.find("eventos").name
    assert_equal "eventos", Niche.find("eventos").to_param
  end

  test "find returns nil for unknown or blank slugs" do
    assert_nil Niche.find("astronomia")
    assert_nil Niche.find(nil)
    assert_nil Niche.find("")
  end

  test "tsquery ORs the include keywords, chains phrases and strips accents and punctuation" do
    niche = Niche.new(slug: "x", name: "X", include_keywords: [ "Comunicação institucional", "redes sociais", "e-mail marketing" ])

    assert_equal "(comunicacao <-> institucional | redes <-> sociais | e <-> mail <-> marketing)", niche.tsquery
  end

  test "tsquery negates the exclude keywords" do
    niche = Niche.new(slug: "x", name: "X", include_keywords: [ "eventos" ], exclude_keywords: [ "eventos adversos", "" ])

    assert_equal "(eventos) & !(eventos <-> adversos)", niche.tsquery
  end

  test "every default preset produces a query PostgreSQL accepts" do
    Niche.all.each do |niche|
      assert_nothing_raised { Tender.connection.select_value(Tender.sanitize_sql_array([ "SELECT to_tsquery('portuguese', ?)", niche.tsquery ])) }
    end
  end

  test "load reads slug, name, description, include and exclude" do
    niches = load_yaml(<<~YAML)
      - slug: limpeza
        name: Limpeza
        description: Conservação predial
        include: [ limpeza, conservação ]
        exclude: [ limpeza de dados ]
    YAML

    niche = niches.sole
    assert_equal "limpeza", niche.slug
    assert_equal "Conservação predial", niche.description
    assert_equal [ "limpeza", "conservação" ], niche.include_keywords
    assert_equal [ "limpeza de dados" ], niche.exclude_keywords
  end

  test "load rejects invalid configuration" do
    assert_raises(Niche::InvalidConfig) { load_yaml("slug: solto") }
    assert_raises(Niche::InvalidConfig) { load_yaml("- slug: sem-palavras\n  name: Sem palavras\n") }
    assert_raises(Niche::InvalidConfig) { load_yaml("- slug: Com Espaco\n  name: X\n  include: [ x ]\n") }
    assert_raises(Niche::InvalidConfig) { load_yaml("- slug: sem-nome\n  include: [ x ]\n") }

    error = assert_raises(Niche::InvalidConfig) do
      load_yaml("- { slug: a, name: A, include: [ x ] }\n- { slug: a, name: B, include: [ y ] }\n")
    end
    assert_match "duplicate niche slugs: a", error.message
  end
end
