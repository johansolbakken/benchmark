# lib/byte.rb

module Byte
  VERSION = '0.0.1'

  def self.parse(s)
    s = s.strip.downcase
    if s.end_with?("gb")
      s[0...-2].to_i * 1024 * 1024 * 1024
    elsif s.end_with?("mb")
      s[0...-2].to_i * 1024 * 1024
    elsif s.end_with?("kb")
      s[0...-2].to_i * 1024
    elsif s.end_with?("b")
      s[0...-1].to_i
    else
      s.to_i
    end
  end
end
