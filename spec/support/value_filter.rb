module Support
  class ValueFilter
    FILTERED_KEYS = [:value]

    # @param [Hash] params
    # @return [Hash]
    def filter(params)
      r = params.dup
      FILTERED_KEYS.each do |key|
        if r.has_key?(key)
          r[key] = "[FILTERED]"
        end
      end
      r
    end
  end
end
