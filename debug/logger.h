#pragma once

#include <fstream>
#include <chrono>
#include <filesystem>
#include <string>

class Logger {
public:
    Logger(const std::string& file)
        : m_filename(file) {
        if (std::filesystem::exists(file)) {
            std::filesystem::remove(file);
        }
        log_file.open(file, std::ios::app);
    }

    std::string timestamp() {
        auto now = std::chrono::system_clock::now();
        std::time_t now_time = std::chrono::system_clock::to_time_t(now);
        auto tm = *std::localtime(&now_time);

        std::ostringstream oss;
        oss << std::put_time(&tm, "%Y-%m-%dT%H:%M:%S");
        return oss.str();
    }


    // Overload the << operator to forward to the ofstream
    template<typename T>
    Logger& operator<<(const T& data) {
        log_file << data;
        return *this;
    }

private:
    std::string m_filename;
    std::ofstream log_file;
};
