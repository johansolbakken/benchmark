use anyhow::{Context, Result}; // Import Result and Context from anyhow
use clap::Parser;
use csv_stddev::calculate_stddev;
use std::fs;

/// Command-line arguments parser using `clap`
#[derive(Parser)]
#[command(name = "CSV StdDev")]
#[command(about = "Calculate standard deviation of a column in a CSV file", long_about = None)]
struct Cli {
    /// Path to the CSV file
    filepath: String,

    /// Name of the column
    column_name: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    // Check if file exists
    fs::metadata(&cli.filepath).context("File does not exist")?;

    let result = calculate_stddev(&cli.filepath, &cli.column_name)
        .context("Failed to calculate standard deviation")?;

    println!(
        "Standard deviation of column '{}': {}",
        cli.column_name, result
    );

    Ok(())
}
