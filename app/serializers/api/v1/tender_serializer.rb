module Api
  module V1
    # A Tender as JSON in API v1 (documented in docs/API.md). Values are decimal strings
    # ("15000.0") to keep their precision; times are ISO 8601 in Brasília time.
    class TenderSerializer
      attr_reader :tender, :urls

      # urls: anything with the app's URL helpers (the controller).
      def initialize(tender, urls)
        @tender = tender
        @urls = urls
      end

      def as_json(*)
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

      private
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
