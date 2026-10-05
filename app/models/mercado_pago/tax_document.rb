# frozen_string_literal: true

module MercadoPago
  # Brazilian CPF (11 digits) / CNPJ (14 digits), check digits included.
  module TaxDocument
    module_function

    def normalize(value)
      value.to_s.gsub(/\D/, "")
    end

    def type(value)
      case normalize(value).length
      when 11 then "CPF"
      when 14 then "CNPJ"
      end
    end

    def valid?(value)
      digits = normalize(value)

      case digits.length
      when 11 then valid_cpf?(digits)
      when 14 then valid_cnpj?(digits)
      else false
      end
    end

    def valid_cpf?(digits)
      return false if digits.squeeze.length == 1

      numbers = digits.chars.map(&:to_i)
      check_digit(numbers.first(9), (2..10).to_a.reverse) == numbers[9] &&
        check_digit(numbers.first(10), (2..11).to_a.reverse) == numbers[10]
    end

    def valid_cnpj?(digits)
      return false if digits.squeeze.length == 1

      numbers = digits.chars.map(&:to_i)
      check_digit(numbers.first(12), [ 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 ]) == numbers[12] &&
        check_digit(numbers.first(13), [ 6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 ]) == numbers[13]
    end

    def check_digit(numbers, weights)
      remainder = numbers.zip(weights).sum { |n, w| n * w } % 11
      remainder < 2 ? 0 : 11 - remainder
    end
  end
end
