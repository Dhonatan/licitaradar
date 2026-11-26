module Api
  module V1
    # A Tender as JSON in API v1 (documented in docs/API.md). Values are decimal strings
    # ("15000.0") to keep their precision; times are ISO 8601 in Brasília time.
    #
    # With `details: true` (GET /api/v1/tenders/:id) it also has the documents and items
    # fetched from the PNCP (Tenders::FetchDetails) and their status.
    class TenderSerializer
      attr_reader :tender, :urls

      # urls: anything with the app's URL helpers (the controller).
      def initialize(tender, urls, details: false)
        @tender = tender
        @urls = urls
        @details = details
      end

      def as_json(*)
        json = attributes
        json.merge!(details_json) if @details
        json
      end

      private
        def attributes
          {
            id: tender.id,
            pncp_control_number: tender.pncp_control_number,
            year: tender.year,
            sequence: tender.sequence,
            purchase_number: tender.purchase_number,
            process_number: tender.process_number,
            object: tender.object_description,
            additional_info: tender.additional_info,
            modality: { id: tender.modality_id, name: modality_name },
            dispute_mode: tender.dispute_mode_name,
            status: { id: tender.status_id, name: tender.status_name },
            open_for_proposals: tender.open_for_proposals?,
            price_registration: tender.price_registration,
            estimated_value: (decimal(tender.estimated_value) unless tender.confidential_value?),
            confidential_value: tender.confidential_value?,
            awarded_value: decimal(tender.awarded_value),
            proposals_open_at: tender.proposals_open_at&.iso8601,
            proposals_close_at: tender.proposals_close_at&.iso8601,
            published_at: tender.published_at&.iso8601,
            source_updated_at: tender.source_updated_at&.iso8601,
            agency: { cnpj: tender.agency_cnpj, name: tender.agency_name, sphere: tender.agency_sphere, power: tender.agency_power },
            unit: { code: tender.unit_code, name: tender.unit_name },
            location: { city: tender.city, state: tender.state, ibge_code: tender.ibge_code },
            links: {
              self: urls.api_v1_tender_url(tender),
              page: urls.tender_url(tender),
              pncp: http_url(tender.pncp_url),
              origin: http_url(tender.origin_url)
            }
          }
        end

        # documents/items are null until the first fetch, [] when the PNCP lists none.
        def details_json
          fetched = tender.details_fetched?
          {
            details: {
              status: details_status,
              fetched_at: tender.details_fetched_at&.iso8601
            },
            documents: (tender.documents.map { |document| document_json(document) } if fetched),
            items: (tender.items.map { |item| item_json(item) } if fetched)
          }
        end

        def details_status
          if tender.details_fetched?
            tender.details_stale? ? "refreshing" : "available"
          else
            tender.details_fetchable? ? "pending" : "unavailable"
          end
        end

        def document_json(document)
          {
            sequence: document.sequence,
            title: document.title,
            type: { id: document.type_id, name: document.type_name },
            url: http_url(document.url),
            published_at: document.published_at&.iso8601
          }
        end

        def item_json(item)
          {
            number: item.number,
            description: item.description,
            kind: { "M" => "material", "S" => "service" }[item.material_or_service],
            quantity: decimal(item.quantity),
            unit: item.unit,
            unit_estimated_value: decimal(item.unit_estimated_value),
            total_estimated_value: decimal(item.total_estimated_value),
            confidential_value: item.confidential_value?,
            status: item.status_name,
            judgment_criterion: item.judgment_criterion_name,
            benefit: item.benefit_name,
            category: item.category_name,
            source_updated_at: item.source_updated_at&.iso8601
          }
        end

        def modality_name
          tender.modality_name.presence || (Pncp::Modalities.name_for(tender.modality_id) if tender.modality_id)
        end

        def decimal(value)
          value&.to_d&.to_s("F")
        end

        # Only http(s) URLs (the origin URL comes from third-party systems).
        def http_url(url)
          uri = URI.parse(url.to_s.strip)
          uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present?
        rescue URI::InvalidURIError
          nil
        end
    end
  end
end
