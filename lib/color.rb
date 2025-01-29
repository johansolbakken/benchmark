# lib/color.rb

module Color
  VERSION = '0.0.1'

  class << self
    # ANSI escape codes for text styles and colors
    RESET = "\e[0m"
    BOLD = "\e[1m"
    GRAY = "\e[90m"
    RED = "\e[31m"
    GREEN = "\e[32m"
    YELLOW = "\e[33m"
    BLUE = "\e[34m"

    # Apply bold formatting
    def bold(text)
      "#{BOLD}#{text}#{RESET}"
    end

    # Apply gray color formatting
    def gray(text)
      "#{GRAY}#{text}#{RESET}"
    end

    # Apply red color formatting
    def red(text)
      "#{RED}#{text}#{RESET}"
    end

    # Apply green color formatting
    def green(text)
      "#{GREEN}#{text}#{RESET}"
    end

    # Apply yellow color formatting
    def yellow(text)
      "#{YELLOW}#{text}#{RESET}"
    end

    # Apply blue color formatting
    def blue(text)
      "#{BLUE}#{text}#{RESET}"
    end

    # Apply both bold and gray formatting
    def bold_gray(text)
      "#{BOLD}#{GRAY}#{text}#{RESET}"
    end
  end
end
